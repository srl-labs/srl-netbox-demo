# srl_netbox-demo

This project sets up a demo environment for Nokia SRL devices using Netbox. The deployment process initializes a virtual network topology using `containerlab` and provisions it using `Netbox` and `Ansible`. During the spin-up, Netbox is deployed, and Nokia device types are imported using the provided device library. After this initial setup, a custom Netbox script is executed to deploy the `containerlab` configuration as Netbox objects.

## Deployment Steps

## Clone the repo
```bash
git clone --recursive https://github.com/FloSch62/srl-netbox-demo
```
**_NOTE:_**  Recursive is needed as the script_collection is sub-module

## Prerequisites

1. containerlab installed on your machine. For installation instructions, refer to the [official documentation](https://containerlab.srlinux.dev/install/).

### 1. Deploy the Topology:

Initiate the virtual network topology using the provided YAML file (`srl_netbox.yaml`):

```bash
containerlab deploy -t srl_netbox.yaml
```
**_NOTE:_**  This step will spin up all necessary containers, deploy Netbox, import Nokia device types from this device library, and finally trigger a custom Netbox script to represent the containerlab file as Netbox objects. This can take several minutes (~4-5 minutes on average) to finish! 

### 2. Access your Netbox
After ensuring all containers are running, you can access the Netbox gui via your http://hostip:8000 with the credentials admin:admin

### 3. Create netbox objects:

```bash
ansible-playbook -i inv/ -e intent_dir=/workspaces/srl-netbox-demo/generated_intents --diff playbooks/netbox_generate_intents.yml -t services
```

### 4. Generate Ansible intents from netbox:

```bash
ansible-playbook -i inv/ -e intent_dir=/workspaces/srl-netbox-demo/generated_intents --diff playbooks/netbox_generate_intents.yml -t services
```

## Topology Overview

![Drawio Example](/img/topo.png)

The deployed topology consists of multiple Nokia SRL nodes such as spines, leaves, and utility containers for tools like Postgres, Redis, and Netbox. For detailed configuration and interconnections, refer to the `srl_netbox.yaml` file.


## Troubleshooting 

### **_Important NOTE:_**  
- The container lab initialization might take several minutes.
- Ensure firewall and proxy settings, if any, permit the communication as per the given topology.

During the deployment process, you might encounter a few hiccups. Here are some common issues and their solutions:

### Monitoring Docker Logs for netbox

If you want to monitor the deployment progress or diagnose any issues, you can check the logs of the netbox container:

```bash
docker logs -f netbox
```

During the initialization, after the database setup, expect to see numerous API calls importing the Nokia devices. If there's a delay or a failure, it might be related to the speed at which the API token is generated in Netbox (check the sleeps in import.sh )
