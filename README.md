# Boundary Enterprise - SSH Key Injection Demo Code

- with ssh Injection



![Monosnap Boundary Demo | onemodel 2024-02-19 13-50-54](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/Monosnap%20Boundary%20Demo%20%7C%20onemodel%202024-02-19%2013-50-54.png)



## 1. Provisioning & Preparing



### 1.1 AWS infra

<https://developer.hashicorp.com/boundary/docs/install-boundary/install>

```hcl
# Set terraform.tfvars
boundary_lic_path = "<my_license_file_path>"
```

```sh
terraform -chdir=01_AWS init
terraform -chdir=01_AWS apply -auto-approve
```

### 1.2 Boundary Setup

```sh
terraform -chdir=02_Boundary init
terraform -chdir=02_Boundary apply -auto-approve
```

### 1.3 Boundary Client

<https://developer.hashicorp.com/boundary/install#desktop-client>



## 2. Test



### 2.1 Boundary Admin Consol Check

[Login : Web Browser]

![image-20240219133936019](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219133936019.png)



[Org → Project → Targets]

![image-20240219133712292](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219133712292.png)

[Target : Host Sources]

![image-20240219133821273](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219133821273.png)

[Target : Injected Applicatin Credential]

![image-20240219133902489](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219133902489.png)



### 2.2 Boundary Client

[Setup Cluster URL]

![image-20240219132625628](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219132625628.png)

[Login Name / Password]

![image-20240219132747695](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219132747695.png)

[Target Check & Connect Button Click]

![image-20240219132857095](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219132857095.png)

[Host Select]

![image-20240219132952482](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219132952482.png)

[Session Ready]

![image-20240219133045012](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219133045012.png)

[Session Status]

![image-20240219133120882](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219133120882.png)

[SSH Key Injection - Auto Login]

![image-20240219133216683](https://raw.githubusercontent.com/Great-Stone/images/master/picgo/image-20240219133216683.png)


## 3. Clear Infra

```sh
terraform -chdir=02_Boundary destroy
terraform -chdir=01_AWS destroy
```