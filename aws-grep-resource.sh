#!/bin/bash

#Creates a VPC and retrieves its ID and assigns it to a variable
VpcID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 | grep -Po '"VpcId": *\K"[^"]*"' | sed 's/"//g')  

echo "VPC: $VpcID"
aws ec2 create-tags --resources $VpcID --tags Key=Name,Value=MY-CLI-VPC

#Creates a subnet and retrieves its ID and assigns it to a variable
PublicSubnet=$(aws ec2 create-subnet --vpc-id $VpcID --cidr-block 10.0.1.0/24 | grep -Po '"SubnetId": *\K"[^"]*"' | sed 's/"//g')
echo "Public Subnet: $PublicSubnet"
aws ec2 create-tags --resources $PublicSubnet --tags Key=Name,Value=MY-CLI-Public-Subnet

#Creates a subnet and retrieves its ID and assigns it to a variable
PrivateSubnet=$(aws ec2 create-subnet --vpc-id $VpcID --cidr-block 10.0.0.0/24 | grep -Po '"SubnetId": *\K"[^"]*"' | sed 's/"//g')
echo "Private Subnet: $PrivateSubnet"
aws ec2 create-tags --resources $PrivateSubnet --tags Key=Name,Value=MY-CLI-Private-Subnet

#Creates IGW and Retrieves Internet Gateway ID and assigns it to a variable
IGW=$(aws ec2 create-internet-gateway | grep -Po '"InternetGatewayId": *\K"[^"]*"' | sed 's/"//g' )
echo "My IGW: $IGW"
aws ec2 create-tags --resources $IGW --tags Key=Name,Value=MY-CLI-IGW

# Attaches the Internet Gateway to a VPC
aws ec2 attach-internet-gateway --vpc-id $VpcID --internet-gateway-id $IGW
echo "VPC: $VpcID has been attached to IGW: $IGW"

#Creates Route Table and retrieves its ID and assigns it to a variable
PublicRouteTable=$(aws ec2 create-route-table --vpc-id $VpcID | grep -Po '"RouteTableId": *\K"[^"]*"' | sed 's/"//g')
echo "Public Route Table: $PublicRouteTable"
aws ec2 create-tags --resources $PublicRouteTable --tags Key=Name,Value=MY-CLI-Public-Route-Table

# Creates Route Table and retrieves its ID and assigns it to a variable
PrivateRouteTable=$(aws ec2 create-route-table --vpc-id $VpcID | grep -Po '"RouteTableId": *\K"[^"]*"' | sed 's/"//g')
echo "Private Route Table: $PrivateRouteTable"

aws ec2 create-tags --resources $PrivateRouteTable --tags Key=Name,Value=MY-CLI-Private-Route-Table

# Attaches the Internet Gateway to the Public Route Table to allow internet traffic
aws ec2 create-route --route-table-id $PublicRouteTable --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW &> /dev/null
echo "Internet Gateway: $IGW  has been attached to Public Route Table: $PublicRouteTable"

# Associates the Public Subnet to the Public Route Table
aws ec2 associate-route-table  --subnet-id $PublicSubnet --route-table-id $PublicRouteTable &> /dev/null
echo "Public Subnet: $PublicSubnet has been associated to the Public Route Table: $PublicRouteTable"

# Modifies the Public Subnet to auto-assign public IPV4 addresses to instances on this subnet  
aws ec2 modify-subnet-attribute --subnet-id $PublicSubnet --map-public-ip-on-launch

MyKey=OurNewKey

aws ec2 create-key-pair --key-name $MyKey --query 'KeyMaterial' --output text > $MyKey.pem

echo "Key Pair has been generated"
echo "Key Pair granted execute Permission"
#Comment this out if you're using a Windows Machine
chmod 400 $MyKey.pem

SSHSecGroup=$(aws ec2 create-security-group --group-name SSH-Script-SG --description \
"Security group for SSH access" --vpc-id $VpcID \
| grep -Po '"GroupId": *\K"[^"]*"' | sed 's/"//g')

# SSHSecGroup=$(aws ec2 create-security-group --group-name SSH-Script-SG --description ^
# "Security group for SSH access" --vpc-id $VpcID ^
# | grep -Po '"GroupId": *\K"[^"]*"' | sed 's/"//g')

aws ec2 authorize-security-group-ingress --group-id $SSHSecGroup --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SSHSecGroup --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "Receive Inbound traffic on Port 80 and 22"

InstanceID=$(aws ec2 run-instances --image-id ami-a4827dc9 --count 1 --instance-type t2.micro \
 --key-name $MyKey --security-group-ids $SSHSecGroup --subnet-id $PublicSubnet \
 | grep -Po '"InstanceId": *\K"[^"]*"' | sed 's/"//g')

PublicIPAddress=$(aws ec2 describe-instances --instance-id $InstanceID | grep -Po '"PublicIpAddress": *\K"[^"]*"' | sed 's/"//g')

aws ec2 create-tags --resources $PrivateRouteTable --tags Key=Name,Value=MY-CLI-Private-Route-Table

echo "Will Connect via SSH into Server with Public IP Address: $PublicIPAddress shortly"
echo "Executed: ssh -i "$MyKey.pem" ec2-user@$PublicIPAddress"

sleep 60

ssh -i "$MyKey.pem" ec2-user@$PublicIPAddress























