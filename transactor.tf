data "aws_dynamodb_table" "table" {
  name = "${var.dynamo_table}"
}

data "aws_vpc" "vpc" {
  tags {
    Name = "${var.vpc_name}"
  }
}

data "aws_subnet" "subnet" {
  filter {
    name = "tag:Name"
    values = [
      "${var.subnet_name}"
    ]
  }
}

data "aws_iam_role" "peer" {
  name = "${var.peer_role_name}"
}

resource "aws_iam_role" "transactor" {
  name = "${var.resource_prefix}${var.env}-datomic-transactors-ec2_role"

  assume_role_policy = <<EOF
{"Version": "2012-10-17",
 "Statement":
 [{"Action": "sts:AssumeRole",
   "Principal": {"Service": "ec2.amazonaws.com"},
   "Effect": "Allow",
   "Sid": ""}]}
EOF
}

resource "aws_iam_role_policy" "transactor" {
  name = "${var.resource_prefix}${var.env}-datomic-transactors-dynamo_access_policy"
  role = "${aws_iam_role.transactor.id}"

  policy = <<EOF
{"Statement":
 [{"Effect":"Allow",
   "Action":["dynamodb:*"],
   "Resource":"${data.aws_dynamodb_table.table.arn}"}]}
EOF
}

resource "aws_iam_role_policy" "transactor_cloudwatch" {
  name = "${var.resource_prefix}${var.env}-datomic-transactors-cloudwatch_access_policy"
  role = "${aws_iam_role.transactor.id}"

  policy = <<EOF
{"Statement":
 [{"Effect":"Allow",
   "Resource":"*",
   "Condition":{"Bool":{"aws:SecureTransport":"true"}},
   "Action": ["cloudwatch:PutMetricData", "cloudwatch:PutMetricDataBatch"]}]}
EOF
}

resource "aws_iam_role_policy" "peer_dynamo_access" {
  name = "${var.resource_prefix}${var.env}-datomic-peers-dynamodb_access_policy"
  role = "${data.aws_iam_role.peer.id}"

  policy = <<EOF
{"Statement":
 [{"Effect":"Allow",
   "Action":
   ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Scan", "dynamodb:Query"],
   "Resource":"${data.aws_dynamodb_table.table.arn}"}]}
EOF
}

resource "aws_iam_role_policy" "peer_cloudwatch_logs" {
  name = "${var.resource_prefix}${var.env}-datomic-peers-cloudwatch_logs_access_policy"
  role = "${data.aws_iam_role.peer.id}"

  policy = <<EOF
{"Version": "2012-10-17",
 "Statement":
 [{"Effect": "Allow",
   "Action":
   ["logs:CreateLogGroup", "logs:CreateLogStream",
    "logs:PutLogEvents", "logs:DescribeLogStreams"],
   "Resource": ["arn:aws:logs:*:*:*"]}]}
EOF
}

resource "aws_s3_bucket" "transactor_logs" {
  bucket = "${var.resource_prefix}${var.env}-datomic-transactor-logs"
  region = "${var.region}"

  tags {
    Environment = "${var.env}"
  }
}

resource "aws_iam_role_policy" "transactor_logs" {
  name = "${var.resource_prefix}${var.env}-datomic-s3_logs_access_policy"
  role = "${aws_iam_role.transactor.id}"

  policy = <<EOF
{"Statement":
 [{"Effect": "Allow",
   "Action": ["s3:PutObject"],
   "Resource": ["arn:aws:s3:::${aws_s3_bucket.transactor_logs.id}",
                "arn:aws:s3:::${aws_s3_bucket.transactor_logs.id}/*"]}]}
EOF
}

resource "aws_iam_instance_profile" "transactor" {
  name = "${var.resource_prefix}${var.env}-datomic-transactor_profile"
  role = "${aws_iam_role.transactor.name}"
}

resource "aws_security_group" "datomic" {
  vpc_id = "${data.aws_vpc.vpc.id}"
  name = "${var.resource_prefix}${var.env}-datomic_security_group"
  description = "Allow access to the database from the default vpc"

  ingress {
    from_port = 4334
    to_port = 4334
    protocol = "tcp"
    self = true
    cidr_blocks = [
      "${data.aws_vpc.vpc.cidr_block}",
      "0.0.0.0/0"
    ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags {
    Environment = "${var.env}"
  }
}

data "aws_ami" "transactor" {
  most_recent = true
  owners = [
    "754685078599"]

  filter {
    name = "name"
    values = [
      "datomic-transactor-*"]
  }

  filter {
    name = "virtualization-type"
    values = [
      "${var.transactor_instance_virtualization_type}"]
  }
}

data "template_file" "transactor_user_data" {
  template = "${file("${path.module}/scripts/transactor.sh")}"

  vars {
    xmx = "${var.transactor_xmx}"
    java_opts = "${var.transactor_java_opts}"
    datomic_bucket = "${var.transactor_deploy_bucket}"
    datomic_version = "${var.datomic_version}"
    aws_region = "${var.region}"
    transactor_role = "${aws_iam_role.transactor.name}"
    peer_role = "${var.peer_role_name}"
    memory_index_max = "${var.transactor_memory_index_max}"
    s3_log_bucket = "${aws_s3_bucket.transactor_logs.id}"
    memory_index_threshold = "${var.transactor_memory_index_threshold}"
    cloudwatch_dimension = "${var.resource_prefix}${var.env}-datomic-transactors"
    object_cache_max = "${var.transactor_object_cache_max}"
    license-key = "${var.datomic_license}"
    dynamo_table = "${var.dynamo_table}"
  }
}

resource "aws_launch_configuration" "transactor" {
  name_prefix = "${var.resource_prefix}${var.env}-datomic-transactor-"
  image_id = "${data.aws_ami.transactor.id}"
  instance_type = "${var.transactor_instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.transactor.name}"
  associate_public_ip_address = true
  security_groups = [
    "${aws_security_group.datomic.id}"
  ]
  user_data = "${data.template_file.transactor_user_data.rendered}"

  ephemeral_block_device {
    device_name = "/dev/sdb"
    virtual_name = "ephemeral0"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "transactors" {
  vpc_zone_identifier = [
    "${data.aws_subnet.subnet.id}"
  ]
  name = "${var.resource_prefix}${var.env}-datomic-transactors_autoscaling_group"
  max_size = "${var.transactors}"
  min_size = "${var.transactors}"
  launch_configuration = "${aws_launch_configuration.transactor.name}"

  tag {
    key = "Name"
    value = "${var.resource_prefix}${var.env}-datomic-transactor"
    propagate_at_launch = true
  }

  tag {
    key = "Environment"
    propagate_at_launch = true
    value = "${var.env}"
  }
}

