# 5주차: Terraform으로 배포 환경 구성하기

4주차의 앱·Docker 이미지·배포용 Compose·GitHub Actions를 이어 사용합니다. 이번에는 AWS 콘솔에서 만들던 배포 환경을 Terraform 파일로 정의하고 생성·변경·삭제합니다.

기본 실습은 **`infra/single/`의 새 EC2 한 대**, 선택 시연은 **`infra/scaling/`의 ALB와 Auto Scaling Group**입니다. 두 폴더는 각각 다른 state를 사용합니다. 4주차에 수동으로 만든 EC2를 자동으로 가져오거나 수정하지 않습니다.

명령은 macOS·Linux의 Bash 터미널 기준입니다. Terraform은 **내 컴퓨터**, 앱 확인용 Docker 명령은 **SSH로 접속한 EC2**에서 실행합니다.

## 1. 파일 구성과 기존 코드

| 위치 | 역할 |
| --- | --- |
| `backend/`, `frontend/` | 기존 FastAPI·React 앱 |
| `deploy/compose.yaml` | 기존 이미지·환경 변수·포트·볼륨·상태 검사 설정 |
| `deploy/deploy.sh` | 기존 앱 배포 명령 |
| `.github/workflows/deploy.yml` | 기존 검사·이미지 게시·앱 배포 |
| `infra/.gitignore` | 실제 입력값·state·다운로드한 provider를 Git에서 제외 |
| `infra/single/` | 자기 앱을 실행할 EC2 한 대와 보안 그룹 |
| `infra/scaling/` | 서버 수 변경과 복구를 확인할 별도 시연 환경 |

`single/`은 기존 Compose 전체를 사용합니다. 프로젝트 이름 `study-app`과 볼륨 `study-app_task-data`도 유지합니다. EC2의 저장소 폴더는 현재 workflow와 같은 **`~/fullstack-study`**입니다.

`scaling/`은 할 일 앱의 복제본을 만드는 실습이 아닙니다. 서버 이름을 반환하는 데이터 없는 HTTP 서버를 사용해 요청 분산과 인스턴스 복구를 확인합니다.

## 2. 도구 준비와 AWS 로그인

### 2.1 도구 확인

[Terraform 설치 안내](https://developer.hashicorp.com/terraform/install)와 [AWS CLI 설치 안내](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)를 참고합니다. 코드의 Terraform 버전 범위는 1.7 이상 2.0 미만이며, AWS provider는 6.32.1 이상 7.0 미만입니다. `aws login`에는 AWS CLI 2.32.0 이상이 필요합니다.

내 컴퓨터에서 확인합니다.

```bash
terraform version
aws --version
```

### 2.2 실습 계정으로 로그인

내 컴퓨터에서 실행합니다.

```bash
aws login --profile study
aws sts get-caller-identity --profile study
```

첫 명령이 연 브라우저에서 실습 계정으로 로그인하고 CLI 사용을 승인합니다. 리전을 물으면 `ap-northeast-2`를 입력합니다. 두 번째 명령의 `Account`가 실습 계정인지 확인합니다.

`study`는 내 컴퓨터에 저장하는 AWS 프로필 이름입니다. Terraform의 `aws_profile`에 같은 이름을 적으면 AWS provider가 이 로그인 정보를 사용합니다. 세션이 만료되면 첫 명령으로 다시 로그인합니다.

AWS 계정에는 해당 리소스를 조회·생성·변경·삭제할 권한이 필요합니다. `aws login`을 쓰는 IAM 사용자나 역할에는 `SignInLocalDevelopmentAccess` 권한도 필요합니다. IAM Identity Center를 쓰는 계정은 [SSO 설정 안내](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)를 따르고, 사용할 프로필 이름을 `aws_profile`에 적습니다.

[AWS CLI 로그인](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html) · [AWS provider의 로그인 지원 확인](https://github.com/hashicorp/terraform-provider-aws/issues/45316) · [AWS SDK의 Login credentials](https://docs.aws.amazon.com/sdk-for-go/v2/developer-guide/configure-gosdk.html)

## 3. Terraform이 사용하는 파일

### 3.1 코드와 입력값

| 파일 | 작성하는 사람과 역할 |
| --- | --- |
| `*.tf` | 개발자가 어떤 리소스를 만들지 정의 |
| `terraform.tfvars.example` | 개발자가 제공하는 입력 예시 |
| `terraform.tfvars` | 실습자가 자기 계정·환경의 실제 값을 입력 |
| `.terraform.lock.hcl` | Terraform이 선택한 provider 버전과 검증 정보를 기록 |
| `terraform.tfstate` | Terraform이 코드와 실제 리소스의 연결을 기록 |

`.example` 파일은 자동으로 적용되지 않습니다. `terraform.tfvars`로 복사해 실제 값을 채웁니다. 같은 폴더의 `terraform.tfvars`는 Terraform 명령을 실행할 때 자동으로 읽습니다.

변수 선언, 입력값, 코드에서의 참조는 다음처럼 연결됩니다.

`variables.tf`에서 입력받을 항목을 선언합니다.

```hcl
variable "web_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
```

`terraform.tfvars`에서는 사용할 값을 적습니다.

```hcl
web_cidrs = ["203.0.113.10/32"]
```

`network.tf`의 보안 그룹 규칙은 `var.web_cidrs`로 그 값을 읽습니다.

```hcl
ingress {
  from_port   = 8080
  to_port     = 8080
  protocol    = "tcp"
  cidr_blocks = var.web_cidrs
}
```

위 IP는 설명용 예시입니다. 실습에서는 자기 공인 IPv4를 사용합니다. 실제 `variables.tf`에는 잘못된 CIDR 입력을 확인하는 검사도 들어 있습니다.

### 3.2 Provider와 관리 기록

Provider는 Terraform이 AWS API를 사용할 수 있게 하는 구성 요소입니다. 이 예제의 provider는 입력한 리전과 프로필을 사용합니다.

```hcl
provider "aws" {
  region  = var.region
  profile = var.aws_profile
}
```

Terraform은 리소스를 생성한 뒤 `aws_instance.app` 같은 코드 주소와 `i-...` 같은 실제 AWS ID의 대응을 **state**에 기록합니다. 이후 변경이나 삭제를 할 때 이 기록을 사용합니다. State는 직접 작성하는 설정 파일이 아닙니다.

`.tf`와 `.terraform.lock.hcl`은 Git에 포함합니다. 실제 입력값 `terraform.tfvars`, state와 `.terraform/`는 제외합니다. 리소스를 정리하기 전에 state를 지우거나 실습 폴더를 버리지 않습니다.

### 3.3 기본 실행 흐름

실습할 Terraform 폴더에서 실행합니다.

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

| 명령 | 하는 일 |
| --- | --- |
| `init` | Provider 설치와 작업 폴더 초기화 |
| `fmt` | Terraform 코드 형식 정리 |
| `validate` | 문법과 구성 확인 |
| `plan` | 현재 상태와 설정을 비교해 변경 예정 내용 표시 |
| `apply` | 계획을 다시 표시하고 승인 후 실제 변경 |

계획의 `+`는 생성, `~`는 변경, `-/+`는 삭제 후 재생성입니다. `plan`만 실행해서는 AWS 리소스가 만들어지지 않습니다. `apply`의 내용을 확인하고 맞을 때 `yes`를 입력합니다.

[입력 변수](https://developer.hashicorp.com/terraform/language/values/variables) · [State](https://developer.hashicorp.com/terraform/language/state) · [Lock file](https://developer.hashicorp.com/terraform/language/files/dependency-lock) · [Plan](https://developer.hashicorp.com/terraform/cli/commands/plan)

## 4. 단일 EC2 실습의 설정값 준비

### 4.1 파일 역할

| `infra/single/` 안의 파일 | 역할 |
| --- | --- |
| `versions.tf` | Terraform·provider 버전과 AWS 접속 설정 |
| `variables.tf` | 입력값 선언과 검사 |
| `network.tf` | 선택한 기존 서브넷 조회와 보안 그룹 생성 |
| `main.tf` | AMI·키 확인과 EC2 생성 |
| `outputs.tf` | 생성 결과의 주소와 ID 표시 |
| `bootstrap.sh.tftpl` | EC2 첫 부팅에 실행할 준비·배포 스크립트 |
| `terraform.tfvars.example` | 자기 값으로 바꾸기 위한 입력 예시 |

### 4.2 리전·키·AMI·서브넷 확인

AWS 콘솔에서 4주차에 사용한 리전을 선택합니다. 기존 Ubuntu 24.04 x86_64 EC2가 있다면 그 인스턴스의 정보를 참고할 수 있습니다.

| 확인할 위치 | 가져올 값 |
| --- | --- |
| EC2 → 인스턴스 → 세부 정보 | AMI ID, 인스턴스 유형, 키 페어 이름 |
| 같은 인스턴스 → 네트워킹 | 서브넷 ID |
| VPC → 서브넷 → 라우팅 테이블 | `0.0.0.0/0`이 `igw-...`로 가는 경로 |
| 보안 그룹 → 인바운드 규칙 편집 → 내 IP | 자기 공인 IPv4의 `/32` 값. 확인 후 저장하지 않고 취소 |

서브넷은 EC2를 배치할 네트워크 영역입니다. 이번 실습은 인터넷 게이트웨이로 가는 경로가 있는 **퍼블릭 서브넷**을 선택합니다. AMI, 키 페어, 서브넷은 모두 `region`과 같은 리전의 값이어야 합니다.

AMI는 Canonical의 **Ubuntu Server 24.04 LTS, 64-bit x86**를 사용합니다. 인스턴스 유형은 자기 계정에서 **프리 티어 사용 가능** 표시가 있는 x86_64 유형을 고르고, 적용 기간과 잔여 크레딧도 확인합니다. `t3.micro`는 해당 표시가 있을 때의 예시입니다.

키 페어는 내 컴퓨터에 보관한 `.pem`과 대응하는 이름을 사용합니다. 없다면 **EC2 → Key pairs → Create key pair**에서 이름 `study-key`, 유형 **RSA**, 형식 **.pem**으로 먼저 만들고 파일을 다운로드합니다. Terraform은 그 키를 조회해 인스턴스를 생성할 때 연결합니다.

### 4.3 Git 커밋과 Docker 이미지 버전

| 입력 | 무엇을 선택하나 |
| --- | --- |
| `repo_url` | 기존 `deploy/`가 들어 있는 자기 공개 GitHub 저장소 |
| `repo_ref` | 첫 부팅 때 배포 설정을 가져올 Git 커밋의 전체 SHA |
| `dockerhub_username` | 두 공개 이미지가 있는 Docker Hub 계정명 |
| `image_tag` | 첫 실행에 사용할, 두 이미지에 공통으로 존재하는 태그 |

`repo_ref`는 GitHub의 커밋 화면에서 전체 SHA를 복사합니다. 아직 push하지 않은 로컬 커밋은 새 EC2가 받을 수 없습니다. `image_tag`는 Docker Hub의 `study-backend`와 `study-frontend`에서 **Tags**를 열어 확인합니다.

4주차 Actions로 게시한 버전이라면 커밋 SHA가 이미지 태그여서 두 입력이 같을 수 있습니다. 수동으로 게시한 `week4-demo` 같은 태그는 Git 커밋 SHA와 별개의 값입니다. **Git 커밋은 설정 파일의 버전, 이미지 태그는 실행할 앱의 버전**입니다.

### 4.4 tfvars 작성

내 컴퓨터의 저장소 루트에서 시작합니다.

```bash
cd infra/single
cp terraform.tfvars.example terraform.tfvars
```

편집기로 `terraform.tfvars`를 열고 채웁니다.

| 변수 | 값 |
| --- | --- |
| `region` | 사용할 AWS 리전. 예제는 `ap-northeast-2` |
| `aws_profile` | 로그인한 프로필. 예제는 `study` |
| `ami_id` | 같은 리전의 Ubuntu 24.04 x86 AMI ID |
| `instance_type` | 프리 티어 조건을 확인한 인스턴스 유형 |
| `key_name` | 먼저 준비한 키 페어 이름 |
| `subnet_id` | 기존 퍼블릭 서브넷 ID |
| `ssh_cidrs` | SSH를 허용할 IPv4 CIDR 목록. 평소에는 내 IP의 `/32` |
| `web_cidrs` | 8080 웹 접속을 허용할 IPv4 CIDR 목록. 기본값은 `["0.0.0.0/0"]` |
| `repo_url`, `repo_ref` | 공개 GitHub 저장소 주소와 이미 push한 커밋 SHA |
| `dockerhub_username`, `image_tag` | 공개 이미지의 계정명과 존재하는 태그 |

`ssh_cidrs`와 `web_cidrs`는 대괄호로 감싼 목록입니다. `/32`는 IPv4 주소 한 개를 뜻합니다. 실제 `.tfvars`에 AWS 액세스 키, Docker Hub PAT, `.pem` 내용을 넣지 않습니다.

[EC2 프리 티어](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html) · [키 페어 생성](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html) · [VPC 라우팅 테이블](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)

## 5. 단일 EC2 생성과 변경

### 5.1 생성

내 컴퓨터의 `infra/single/`에서 실행합니다.

```bash
terraform init
terraform fmt
terraform validate
terraform plan
```

기존 서브넷·AMI·키는 `data`로 조회하고, 새 보안 그룹과 EC2는 `resource`로 생성합니다. 계획의 리전, AMI, 인스턴스 유형, 키, 22·8080 규칙을 확인합니다.

```bash
terraform apply
terraform output
```

`public_ip`는 SSH와 `EC2_HOST`에 사용할 주소, `web_url`은 브라우저 주소, `security_group_id`는 이번 보안 그룹의 ID입니다. `instance_id`와 `ssh_command`도 출력에서 확인할 수 있습니다.

### 5.2 첫 부팅에서 하는 일

Terraform의 `templatefile`이 `bootstrap.sh.tftpl`에 입력값을 채워 EC2에 전달합니다. EC2는 Docker·Compose·Git을 설치하고, 공개 저장소를 **`/home/ubuntu/fullstack-study`**에 clone한 뒤 `repo_ref`로 지정한 커밋을 선택합니다.

그다음 `deploy/.env`에 이미지 계정과 태그를 적고 기존 Compose로 앱을 실행합니다. 환경 변수, 데이터 볼륨, healthcheck와 서비스 시작 순서는 기존 `deploy/compose.yaml`을 따릅니다.

**`apply` 완료 후에도 첫 부팅 스크립트가 진행 중일 수 있습니다.** 내 컴퓨터의 키 보관 폴더에서 출력된 SSH 명령으로 접속합니다. 다운로드 폴더에 `study-key.pem`을 보관한 경우는 다음과 같습니다.

```bash
cd ~/Downloads
chmod 400 study-key.pem
```

이어서 `ssh_command`를 복사해 실행합니다. 처음 접속할 때의 서버 확인은 [4주차 접속 안내](week4.md#53-다운로드한-키로-ssh-접속)를 참고합니다.

접속한 **EC2 터미널**에서 초기화와 앱 상태를 확인합니다.

```bash
sudo cloud-init status --wait
cd ~/fullstack-study/deploy
sudo docker compose ps
curl -f http://localhost:8080/api/health
```

cloud-init의 성공 완료를 확인하고, 예제의 API가 `{"status":"ok"}`를 응답하는지 봅니다. 내 컴퓨터의 브라우저에서 `web_url`을 열고 앱 기능을 확인합니다.

초기화 오류는 EC2에서 다음 로그로 확인합니다. `q`로 닫습니다.

```bash
sudo less /var/log/cloud-init-output.log
```

### 5.3 변경 연습: 웹 접속을 내 IP로 제한

SSH 접속 중이라면 `exit`로 내 컴퓨터에 돌아옵니다. **내 컴퓨터의 `infra/single/terraform.tfvars`**에서 `web_cidrs`를 수정합니다.

변경 전:

```hcl
web_cidrs = ["0.0.0.0/0"]
```

변경 후, 예시 IP를 자기 실제 공인 IPv4로 바꿉니다.

```hcl
web_cidrs = ["203.0.113.10/32"]
```

같은 `infra/single/` 폴더에서 실행합니다.

```bash
terraform plan
terraform apply
```

**8080 보안 그룹 규칙만 바뀌는지** 확인하고 적용합니다. AWS 콘솔에서 출력된 `security_group_id`를 열어 인바운드 8080의 소스를 확인합니다. SSH 규칙과 앱 버전은 이 연습에서 바꾸지 않습니다.

다시 공개하려면 `web_cidrs`를 `["0.0.0.0/0"]`으로 되돌리고 계획을 확인한 뒤 적용합니다.

[EC2 user data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) · [cloud-init 상태 확인](https://docs.cloud-init.io/en/latest/reference/cli.html#status)

## 6. 기존 CI/CD를 새 EC2에 연결

Terraform은 서버와 보안 그룹을 준비합니다. 이후 앱 업데이트는 4주차 Actions의 검사·이미지 게시·SSH 배포를 계속 사용합니다.

자기 저장소의 **Settings → Secrets and variables → Actions**에서 확인합니다.

| Secret | 새 EC2에 연결할 때 |
| --- | --- |
| `EC2_HOST` | `single` 출력의 새 `public_ip`로 변경 |
| `EC2_SSH_KEY` | 같은 키라면 유지. 다른 키를 연결했다면 그 `.pem` 전체 내용으로 변경 |
| `DOCKERHUB_USERNAME` | 기존 계정명 유지 |
| `DOCKERHUB_TOKEN` | 기존 Repo Read & Write PAT 유지 |

현재 workflow는 `~/fullstack-study`에서 커밋을 갱신하고 `deploy/`의 `deploy.sh`를 실행합니다. 서버의 clone 위치도 이 경로로 맞춰 두었습니다.

`ssh_cidrs`가 내 IP만 허용하면 GitHub-hosted runner는 SSH로 들어올 수 없습니다. **자동 배포 시연 동안** `ssh_cidrs = ["0.0.0.0/0"]`으로 바꾸고 `infra/single/`에서 계획을 확인한 뒤 적용합니다. 시연 뒤에는 내 IP의 `/32` 목록으로 되돌려 적용합니다. 되돌린 뒤에는 hosted runner의 SSH 배포도 차단됩니다.

첫 부팅이 끝난 뒤, 화면에서 확인할 수 있는 문구를 바꾸고 `main`에 push합니다. Actions와 새 EC2 화면에서 결과를 확인합니다. 앱 변경 때마다 `repo_ref`나 첫 실행용 `image_tag`를 Terraform에서 다시 바꾸는 연습은 하지 않습니다.

### 서버 교체와 데이터

이 예제는 `user_data_replace_on_change = true`이므로 `repo_ref`, 첫 실행용 이미지 태그, 부팅 스크립트처럼 user data를 바꾸는 설정을 변경하면 EC2를 교체합니다. AMI 변경도 계획에서 `-/+`와 **forces replacement** 여부를 확인합니다.

할 일 DB는 `single` EC2의 로컬 Docker volume에 있습니다. 같은 EC2에서 Compose를 다시 실행하면 유지되지만 **EC2와 디스크를 교체·삭제하면 DB도 사라집니다.** 필요한 데이터를 먼저 백업합니다.

[GitHub Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)

## 7. 여러 서버로 확장하기: 선택 시연

### 7.1 무엇을 확인하는가

`infra/scaling/`은 별도 환경입니다. `single/`의 EC2나 DB를 수정하지 않습니다.

| 구성 요소 | 역할 |
| --- | --- |
| ALB | HTTP 80으로 받은 요청을 정상 서버에 전달 |
| 대상 그룹 | HTTP 8080 서버 목록과 상태 검사 |
| 시작 템플릿 | 새 EC2의 AMI·유형·보안 그룹·부팅 스크립트 |
| Auto Scaling Group | 희망 서버 수를 유지하고 서버를 대상 그룹에 등록 |

시연 서버는 자기 hostname을 반환하며 데이터를 저장하지 않습니다. 8080은 ALB의 보안 그룹에서 오는 요청만 허용합니다. 시연 EC2에는 SSH 접속을 열지 않습니다.

`scaling/main.tf`에 ALB·대상 그룹·시작 템플릿·ASG를 정의하고, `demo-bootstrap.sh`가 각 EC2의 HTTP 서버를 준비합니다. `variables.tf`와 `terraform.tfvars`의 역할은 기본 실습과 같습니다.

기존 할 일 앱은 SQLite 파일이 각 서버 디스크에 있으므로 그대로 여러 대 복제하면 DB가 나뉩니다. 그래서 데이터 없는 서버로 확장 동작을 먼저 확인합니다. 실제 앱의 다중 서버 운영에서는 공유 DB 등 데이터 저장 구조를 먼저 정리해야 합니다.

### 7.2 서브넷 두 개와 설정 준비

AWS의 **VPC → Subnets**에서 다음 조건의 퍼블릭 서브넷 두 개를 고릅니다.

- 같은 VPC에 속합니다.
- 서로 다른 가용 영역(AZ)에 있습니다.
- 둘 다 `0.0.0.0/0`이 인터넷 게이트웨이 `igw-...`로 가는 경로를 사용합니다.
- 각 서브넷의 CIDR은 `/27` 또는 그보다 넓은 범위(예: `/24`)이고, 사용할 수 있는 IPv4 주소가 8개 이상이어야 합니다. VPC 서브넷 화면에서 CIDR과 Available IPv4 addresses를 확인합니다.

AMI·인스턴스 유형은 `single`과 같은 Ubuntu 24.04 x86_64 기준이며, 자기 계정의 프리 티어 적용 조건을 확인합니다. **ALB와 추가 EC2·디스크·공인 IPv4 사용량은 별도로 발생할 수 있습니다.**

내 컴퓨터의 저장소 루트에서 새 터미널을 열어 실행합니다.

```bash
cd infra/scaling
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`의 `region`, `aws_profile`, `ami_id`, `instance_type`, `subnet_ids`를 자기 값으로 바꾸고 `desired_count = 1`로 시작합니다. 서브넷은 두 ID를 대괄호 목록에 적습니다. 키 페어, Git 저장소와 Docker Hub 입력값은 이 시연에 필요하지 않습니다.

### 7.3 한 대로 생성하고 응답 확인

내 컴퓨터의 `infra/scaling/`에서 실행합니다.

```bash
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

출력값은 다음과 같습니다.

| output | 쓰는 곳 |
| --- | --- |
| `alb_url` | 브라우저·curl로 접속할 ALB 주소 |
| `asg_name` | EC2 콘솔의 Auto Scaling Groups에서 찾을 이름 |
| `target_group_arn` | Target Groups에서 확인할 대상 그룹의 식별값 |

AWS 콘솔의 **EC2 → Target Groups**에서 해당 대상 그룹을 선택하고 **Targets**에서 서버 한 대가 `Healthy`가 될 때까지 기다립니다. `initial`은 검사 준비·진행 중인 상태일 수 있습니다.

브라우저에서 출력된 `alb_url`을 열면 `ip-...` 형태의 서버 이름이 표시됩니다. ALB의 상태 검사는 HTTP `/` 응답을 확인하며, 앞선 Compose의 healthcheck와 별개의 검사입니다.

### 7.4 서버 수를 1대에서 2대로 변경

같은 폴더의 `terraform.tfvars`에서 수정합니다.

```hcl
desired_count = 2
```

내 컴퓨터의 `infra/scaling/`에서 실행합니다.

```bash
terraform plan
terraform apply
```

AWS의 **Auto Scaling Groups**에서 출력된 그룹을 선택하고 인스턴스가 두 대인지 확인합니다. 대상 그룹에서도 두 대상이 모두 `Healthy`인지 확인합니다.

출력된 전체 ALB URL을 사용해 요청을 여러 번 보내거나 브라우저를 새로고침합니다. 다음 명령의 주소는 자기 출력값으로 바꿉니다.

```bash
curl http://실제-ALB-DNS-이름
```

서로 다른 hostname을 관찰할 수 있습니다. 응답이 매번 반드시 A/B 순서로 번갈아 나오는 것은 아닙니다.

### 7.5 한 대를 종료하고 복구 확인

1. **Auto Scaling Groups → 해당 그룹 → Instance management**에서 시연 인스턴스 ID를 확인합니다.
2. **EC2 → Instances**에서 그중 한 대를 선택합니다. `single` 실습 EC2와 구분합니다.
3. **Instance state → Terminate (delete) instance**로 선택한 한 대를 종료합니다.
4. ASG의 **Activity**에서 새 인스턴스 생성 기록을 확인합니다.
5. 그룹이 희망 수인 두 대로 돌아오고 대상 그룹에서도 두 대상이 `Healthy`가 되는지 확인합니다.

이때 `desired_count`는 2로 유지합니다. 한 대를 직접 종료해도 ASG가 희망 수를 맞추므로, 이 방법으로 시연 전체를 정리할 수는 없습니다. 실습 종료에는 아래 `terraform destroy`를 사용합니다.

이번 시연은 **희망 수를 직접 변경하는 것과 인스턴스 복구**를 확인합니다. CPU 부하에 따라 수를 자동 조절하려면 별도의 확장 정책이 필요하며, 이번 코드에는 그 정책을 넣지 않았습니다.

[ALB의 서브넷 조건](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html) · [ALB 상태 검사](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html) · [ASG 수동 용량 변경](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scaling-manually.html)

## 8. State와 비용 정리

### 8.1 두 폴더는 별도 관리 기록

`infra/single/terraform.tfstate`와 `infra/scaling/terraform.tfstate`는 서로 다른 리소스를 기록합니다. `single/`에서 `destroy`해도 `scaling/`의 ALB와 ASG는 지워지지 않습니다. 각 실습을 실행한 폴더에서 정리해야 합니다.

Git에는 `.tf`, 템플릿, `.terraform.lock.hcl`, `.tfvars.example`을 포함합니다. 실제 `.tfvars`, state, `.terraform/`, 개인키는 제외합니다. 리소스를 정리하기 전에 state를 삭제하지 않습니다. 팀이 같은 인프라를 함께 관리할 때는 접근 제어와 잠금이 가능한 원격 state 저장소를 사용합니다.

### 8.2 비용이 생기는 항목

| 항목 | 확인할 내용 |
| --- | --- |
| EC2 | `single` 한 대와 `scaling`이 유지하는 대수의 실행 시간 |
| EBS | 각 EC2의 디스크 용량과 보관 기간 |
| 공인 IPv4 | EC2와 인터넷 연결 ALB가 사용하는 공인 주소 |
| ALB | 생성되어 있는 시간과 처리 사용량 |
| 데이터 전송·스냅샷 | 사용하거나 별도로 만든 경우의 추가 비용 |

프리 티어 유형을 선택해도 모든 항목이 항상 무료인 것은 아닙니다. 계정의 기간·한도·잔여 크레딧을 확인합니다. EC2를 Stop해도 EBS 비용은 남을 수 있고, 시연 인스턴스를 한 대씩 종료해도 ASG가 다시 만들 수 있습니다.

[EC2 요금](https://aws.amazon.com/ec2/pricing/on-demand/) · [EBS 요금](https://aws.amazon.com/ebs/pricing/) · [공인 IPv4 요금](https://aws.amazon.com/vpc/pricing/) · [ALB 요금](https://aws.amazon.com/elasticloadbalancing/pricing/)

### 8.3 폴더별로 삭제

필요한 앱 데이터를 백업하고 실습 화면을 저장합니다. **내 컴퓨터의 저장소 루트**에서 시작합니다.

기본 실습 삭제:

```bash
cd infra/single
terraform plan -destroy
terraform destroy
```

선택 시연도 만들었다면, **저장소 루트의 다른 터미널**에서 실행합니다.

```bash
cd infra/scaling
terraform plan -destroy
terraform destroy
```

각 삭제 목록이 맞는지 읽고 `yes`를 입력합니다. `single`의 EC2와 기본 디스크를 삭제하면 로컬 DB도 삭제됩니다. `scaling`은 ASG, 시연 EC2, ALB, 대상 그룹, 보안 그룹 등을 정리합니다.

기존 서브넷·VPC·키 페어와 4주차 수동 EC2는 이 state가 관리하는 리소스가 아닙니다. 이 작업으로 자동 삭제되지 않습니다. 삭제가 일부 실패했다면 오류를 해결한 뒤 **같은 폴더**에서 `terraform destroy`를 다시 실행합니다.

### 8.4 콘솔에서 마지막 확인

- **EC2 → Instances:** 이번 인스턴스가 종료됐는지 확인합니다.
- **Auto Scaling Groups / Load Balancers / Target Groups:** 선택 시연의 그룹과 ALB 등이 남아 있지 않은지 확인합니다.
- **Volumes:** 실습 EC2에 연결했던 디스크가 남아 있는지 확인합니다. 별도로 만든 실습용 볼륨은 필요한 데이터를 확인한 후 삭제합니다.
- **Snapshots / Elastic IPs:** 직접 만든 항목이 있다면 [4주차 정리 절차](week4.md#103-남은-디스크와-고정-ip-정리)로 정리합니다.
- **Billing and Cost Management → Bills:** 이번 달 서비스·리전별 청구 내역을 확인합니다.

4주차의 수동 EC2가 남았다면 그 서버도 별도로 정리합니다. 리소스를 삭제해도 이미 사용한 요금은 남으며 청구 화면 반영에 시간이 걸릴 수 있습니다.

[Terraform destroy](https://developer.hashicorp.com/terraform/cli/commands/destroy) · [EC2 종료](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html) · [EBS 삭제](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-deleting-volume.html) · [Bills 확인](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/getting-viewing-bill.html)

## 9. 코드 검사

각 폴더의 `tests/`는 mock provider로 구성과 입력값을 검사합니다. 이 테스트는 실제 AWS 리소스를 만들지 않습니다. 저장소 루트에서 실행합니다.

```bash
cd infra/single
terraform init
terraform validate
terraform test
```

이어서 선택 시연 구성도 검사할 수 있습니다.

```bash
cd ../scaling
terraform init
terraform validate
terraform test
```

이 수정본을 작성한 환경에서는 `terraform fmt`, 부팅 스크립트의 Bash 문법 검사, 시연 HTTP 서버의 실제 로컬 응답 확인을 마쳤습니다. Provider 설치도 확인했지만, 환경의 Unix socket 제한으로 `terraform validate`와 mock 테스트는 실행을 완료하지 못했습니다. 실제 AWS의 인증·생성·배포·삭제는 실행하지 않았습니다.

[Terraform mock 테스트](https://developer.hashicorp.com/terraform/language/tests/mocking)

## 9. 실습 완료와 문제 확인

기본 실습은 자기 프로젝트를 `single`로 실행하고, `web_cidrs` 변경으로 보안 그룹 규칙이 바뀌는 것을 확인합니다. 기존 Actions를 새 EC2에 연결한 결과와 커밋 이력을 README에 남긴 뒤 리소스를 정리합니다. 모든 사람이 강사의 할 일 앱을 그대로 사용할 필요는 없습니다.

| 문제 | 먼저 볼 곳 |
| --- | --- |
| AWS 인증 오류 | 로그인 세션, `aws_profile`, `aws sts get-caller-identity --profile study` |
| AMI·키·서브넷 조회 실패 | 입력 ID와 `region`이 같은 리전인지 |
| Git checkout 실패 | `repo_ref`가 그 공개 저장소에 push된 커밋인지 |
| 이미지 pull 실패 | 두 이미지의 공개 여부, 계정명과 존재하는 태그 |
| 앱이 바로 열리지 않음 | EC2의 cloud-init 완료와 초기화 로그 |
| 변경 후 웹 접속 불가 | `web_cidrs`에 현재 공인 IP가 포함되는지 |
| Actions SSH 접속 실패 | 새 `EC2_HOST`, 연결된 키, `ssh_cidrs` |
| ALB 응답 실패 | 대상 상태, 8080 서버, ALB에서 대상까지의 보안 그룹 규칙 |
| ASG가 계속 서버를 다시 만듦 | 시연 종료는 인스턴스 개별 종료 대신 해당 폴더의 `destroy` 사용 |
