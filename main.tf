#data "aws_security_group" "terraform-sg1" {}
data "aws_availability_zones" "available" {}

resource "aws_kms_key" "test_key" {
   description             = "This key is used to encrypt bucket objects"
   deletion_window_in_days = 10
}


resource "aws_security_group" "sg1" {
  name = "terraform-sg2"

#  vpc_id   = "${var.vpc_id}"

vpc_id   = "vpc-replace with vpc_id"

# vpc_id   = "${aws_default_vpc.default.id}"

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
#    prefix_list_ids = ["pl-12c4e678"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}



resource "aws_s3_bucket" "elb" {
  bucket = "lb2-test-bucket"
  acl    = "private"
policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::797873946194:root"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::lb1-test-bucket/*"
        }
    ]
}
EOF
  tags = {
    Name        = "Log bucket"
    Environment = "Dev"
  }

   server_side_encryption_configuration {
     rule {
       apply_server_side_encryption_by_default {
         kms_master_key_id = "${aws_kms_key.test_key.arn}"
         sse_algorithm     = "aws:kms"
       }
     }
   }

  lifecycle_rule {
    id      = "log"
    enabled = true

    prefix = "log/"

  tags = {
      "rule"      = "log"
      "autoclean" = "true"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA" # or "ONEZONE_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 730
    }
  }

  lifecycle_rule {
    id      = "tmp"
    prefix  = "tmp/"
    enabled = true

    expiration {
      date = "2020-01-12"
    }
  }
}



output "s3_bucket_arn" {
  value = "${aws_s3_bucket.elb.arn}"
}

resource "aws_elb" "elb1" {

name = "terraform-elb1"
#availability_zones = ["${data.aws_availability_zones.available.names}"]
subnets 	    = ["subnet1-id","subnet2-id"]
security_groups = ["${aws_security_group.sg1.id}"]
access_logs {
bucket = "lb2-test-bucket"
bucket_prefix = "elb"
interval = 5
}
listener {
instance_port = 80
instance_protocol = "http"
lb_port = 80
lb_protocol = "http"
}

health_check {
healthy_threshold = 2
unhealthy_threshold = 2
timeout = 3
target = "HTTP:80/"
interval = 30
}

#instances = ["${aws_instance.test_instance_a.id}"]
cross_zone_load_balancing = true
idle_timeout = 400
connection_draining = true
connection_draining_timeout = 400

tags {
Name = "terraform-elb1"
}
}

