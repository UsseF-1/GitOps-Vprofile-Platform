resource "aws_ecr_repository" "app" {
    name = "vprofile-app"

    image_tag_mutability = "MUTABLE"

    image_scanning_configuration {
        scan_on_push = true
    }

    force_delete = true

    tags = {
        Name = "vprofile-app"
    }
}


resource "aws_ecr_repository" "db" {
    name = "vprofile-db"

    image_tag_mutability = "MUTABLE"

    image_scanning_configuration {
        scan_on_push = true
    }

    force_delete = true

    tags = {
        Name = "vprofile-db"
    }
}


resource "aws_ecr_repository" "web" {
    name = "vprofile-web"

    image_tag_mutability = "MUTABLE"

    image_scanning_configuration {
        scan_on_push = true
    }

    force_delete = true

    tags = {
        Name = "vprofile-web"
    }
}