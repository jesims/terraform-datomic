# AWS Datomic

This module can be used to deploy AWS datomic transactor and dynamodb.

Module Input Variables
----------------------

Check [variables.tf](./variables.tf)

Usage Example
-----

```hcl
module datomic {
  source = "github.com/jesims/terraform-datomic"
  datomic_license = "${var.datomic_license}"
  peer_role_name = "some-peer-name"
  region = "${var.region}"
  subnet_name = "my-subnet"
  vpc_name = "my-vpc"
}
```

Author
------
Created by [Fierce Ventures](https://github.com/fierceventures/), modified by [JESI](https://github.com/jesims/)
