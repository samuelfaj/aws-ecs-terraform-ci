Ideia de post: Utilizando ECS com Terraform e Gitlab CI

Em algum momento, você já deve ter se deparado com a seguinte questão: "Como gerenciar e atualizar múltiplos serviços rodando simultaneamente no meu servidor?" A resposta para este desafio, na verdade, é mais simples do que parece. Neste post, iremos explorar uma maneira eficiente e elegante de resolver esse problema. Vamos abordar a criação de um container individual para cada serviço, a utilização do AWS ECS para gerenciá-los de forma eficaz e, por fim, a implementação do Gitlab CI para garantir atualizações consistentes e sem esforço desses containers. Continue lendo e descubra como tornar a gestão do seu servidor um processo mais tranquilo e eficiente!

Capitulo 1: Terraform

O Terraform é uma ferramenta que permite escrever infraestrutura como código (IaC), facilitando o gerenciamento e a automação de recursos de TI.

Iniciamos a configuração criando um arquivo chamado main.tf. Este arquivo será a base da nossa infraestrutura.

```
provider "aws" {
    region = "us-east-1"
}
```

Este código especifica que estaremos utilizando a AWS como provedor de infraestrutura, especificamente na região us-east-1.

Em seguida, criamos o arquivo aws-ecs.tf. Este arquivo será responsável por criar o cluster do AWS ECS e definir suas permissões:

```
resource "aws_ecs_cluster" "devninja_worker" {
  name = "devninja_worker"
}

resource "aws_iam_role" "ecs_role" {
  name = "ecs_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_role_attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_ecr_attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ecs_role.name
}
```

Este código cria um cluster ECS chamado devninja_worker e define uma série de políticas de permissão para o mesmo.

Agora que temos nosso cluster, devemos adicionar uma instância (EC2) a ele.

Para adicionar uma instância ao AWS ECS, é necessário que ela tenha uma imagem de máquina da Amazon (AMI) compatível (Amazon ECS-optimized Amazon Linux 2 AMI). Além disso, ao iniciar a máquina, ela deve executar o comando de inicialização.

Criaremos uma pasta chamada assets e, dentro dela, o arquivo ecs-instance.sh:

assets/ecs-instance.sh

```
#!/bin/bash
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config
```

Este script define a variável ECS_CLUSTER no arquivo de configuração do ECS, que especifica a qual cluster a instância EC2 pertencerá.

Continuamos a configuração com o arquivo aws-ecs-ec2.tf:

```
# Instance
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs_tasks_sg"
  description = "Allow inbound traffic on all ports"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ecs_instance" {
  ami           = "ami-0ebb9b1c37ef501ab" # Replace with the latest Amazon ECS-optimized Amazon Linux 2 AMI
  instance_type = "t3.small"
  key_name      = "ttl-servers"

  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  user_data = templatefile("${path.module}/assets/ecs_instance.sh", { cluster_name = aws_ecs_cluster.ttl_worker.name })

  vpc_security_group_ids = [aws_security_group.ecs_tasks.id]

  tags = {
    Name = "ECS Instance"
  }
}
```

Esse código cria uma instância EC2 e a conecta ao nosso cluster ECS. Note que estamos utilizando a última versão da AMI otimizada para o ECS em uma instância do tipo t3.small.

Agora que temos o cluster AWS ECS configurado e uma máquina EC2 integrada a ele, nós devemos ser capazes de subir nosso Dockerfile para a AWS. Para isso, usaremos o AWS ECR e o arquivo aws-ecr.tf.

```
resource "aws_ecr_repository" "devninja_ecr_1" {
  name                 = "devninja_ecr_1"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}
```

Este código cria um repositório ECR chamado devninja_ecr_1, onde armazenaremos nossas imagens Docker.

Finalmente, é hora de executar nosso container em um serviço do ECS. Cada serviço requer uma 'task definition'. Uma 'task definition' do AWS ECS é um arquivo em formato JSON que descreve um ou mais contêineres que compõem a sua aplicação. Essa definição especifica as configurações dos contêineres, incluindo os recursos que eles precisam, como CPU e memória, além de quais imagens Docker usar, quais portas de rede expor, e muito mais. É, em essência, a 'receita' para a sua aplicação dentro do ambiente AWS ECS.

Para isso, criaremos o arquivo aws-ecs-task.tf:

```
# Define para aparecerem logs

resource "aws_cloudwatch_log_group" "devninja_worker_nodejs" {
  name = "/ecs/devninja_worker_nodejs"
  retention_in_days = 14
}

# Task Definition (usaremos a imagem do apache como exemplo)

resource "aws_ecs_task_definition" "devninja_worker_nodejs" {
  family                   = "devninja_worker_nodejs"
  network_mode             = "bridge"
  cpu                      = "256"
  memory                   = "128"
  requires_compatibilities = ["EC2"]

  container_definitions = <<DEFINITION
  [
    {
      "name": "devninja_worker_nodejs",
      "image": "${aws_ecr_repository.devninja_ecr_1.repository_url}:main",
      "cpu": 256,
      "memory": 128,
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/devninja_worker_nodejs",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  DEFINITION
}

# Adicionando ao cluster nossa task

resource "aws_ecs_service" "devninja_worker_nodejs" {
  name            = "devninja_worker_nodejs"
  cluster         = aws_ecs_cluster.devninja_worker.id
  task_definition = aws_ecs_task_definition.devninja_worker_nodejs.arn
  desired_count   = 1
  launch_type     = "EC2"
}
```

Este bloco de código faz várias coisas. Primeiro, ele cria um grupo de logs no CloudWatch, que armazenará os logs da nossa aplicação. Em seguida, ele define uma 'task definition' para um contêiner contendo a nossa imagem do AWS ECR, incluindo a quantidade de CPU e memória que o contêiner deve usar, e a configuração de log que o contêiner deve seguir.

Finalmente, ele adiciona a nossa 'task definition' ao nosso cluster ECS. Observe que estamos usando o tipo de lançamento "EC2", o que significa que o nosso contêiner será executado em uma instância EC2.

Neste ponto, temos um cluster ECS configurado e rodando com um único serviço. Mas como podemos garantir que as alterações no nosso código sejam refletidas no nosso serviço? A resposta é o Gitlab CI.

Continua...
Espero que até aqui você tenha achado este guia útil. Se tiver alguma dúvida ou sugestão, não hesite em deixar um comentário abaixo!