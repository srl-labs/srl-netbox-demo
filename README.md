# srl_netbox-demo

This project sets up a demo environment for Nokia SRL devices using Netbox. The deployment process initializes a virtual network topology using `containerlab` and provisions it using `Netbox` and `Ansible`. During the spin-up, Netbox is deployed, and Nokia device types are imported using the provided device library. For generating and deploying intents to the fabric, the project is using the playbooks from the [`netbox_integration_example` branch](https://github.com/srl-labs/intent-based-ansible-lab/tree/netbox_integration_example) of the `intent-based-ansible-lab` repository.


---
<div align=center>
<a href="https://codespaces.new/srl-labs/srl-netbox-demo?quickstart=1">
<img src="https://gitlab.com/rdodin/pics/-/wikis/uploads/d78a6f9f6869b3ac3c286928dd52fa08/run_in_codespaces-v1.svg?sanitize=true" style="width:50%"/></a>

**[Run](https://codespaces.new/srl-labs/intent-based-ansible-lab?quickstart=1) this lab in GitHub Codespaces for free**.  
[Learn more](https://containerlab.dev/manual/codespaces/) about Containerlab for Codespaces.

</div>

---

## Deployment Steps

## Clone the repo
```bash
git clone --recursive https://github.com/FloSch62/srl-netbox-demo
```
**_NOTE:_**  Recursive is needed as the script_collection is sub-module

## Prerequisites

Containerlab installed on your machine. For installation instructions, refer to the [official documentation](https://containerlab.srlinux.dev/install/).

### 1. Deploy the Topology:

Initiate the virtual network topology using the provided YAML file (`srl_netbox.yaml`):

![Drawio Example](/img/topo.png)

```bash
sudo clab deploy -t srl_netbox.yaml
```
**_NOTE:_** This step will spin up all necessary containers, deploy Netbox, and start importing Nokia device types from the device library. The entire `clab deploy` process takes about 4-5 minutes. After that, the `netbox_importer` container will continue running for an additional minute to complete the import, becoming healthy once finished.


### 2. Access your Netbox

After ensuring all containers are running, you can access the Netbox GUI in two ways:
- **Locally:** Navigate to `http://hostip:8000` using the credentials `admin:admin`.
- **Via GitHub Codespaces:** If you are running this environment in GitHub Codespaces, the application URL will be provided in the Codespaces port forwarding section.

Both methods will provide you with administrative access to manage and configure the network settings and devices.


### 3. Initialize Netbox:

Navigate to the scripts directory to execute the initialization scripts. These scripts will set up Netbox with necessary configurations and import data.

1. **Import Infrastructure and Initial Settings:**
   - This script initializes Netbox with custom fields and imports infrastructure intents from `intents/netbox_intents/lab01.yaml` and `lags-lab01.yaml`. It triggers an API call to `nokia-srl-netbox-scripts/2_Infrastructure.py`, which imports the fabric configuration from these YAML files.

   ```bash
   bash api_scripts/import_infra.sh
   ```
2. **Import Services:**

   - This script imports service configurations from `intents/netbox_intents/l2vpns-lab01.yaml` and `intents/netbox_intents/l3vpns-lab01.yaml`. It makes an API call to `nokia-srl-netbox-scripts/3_Services.py`, processing these files to import VPN services into Netbox.
  
   ```bash
   bash api_scripts/import_service.sh
   ```

### 4. Generate Ansible intents from Netbox:

Execute the Ansible playbook below to generate intents based on the data stored in Netbox. This playbook can be tailored using the `-t services` option to focus exclusively on generating service configuration intents. Without the `-t services` flag, the playbook generates both host-specific (`host_infra.yml`) and group-specific (`group_infra.yml`) infrastructure intents. The provided `intents/ansible_intents/fabric.yml` is a higher abstraction already available for infrastructure configuration.


```bash
ansible-playbook -i inv/ -e intent_dir=/workspaces/srl-netbox-demo/intents/ansible_intents --diff intent-based-ansible-lab/playbooks/netbox_generate_intents.yml -t services
```


### 5. Deploy generated intents:

After generating the intents, deploy them using the following Ansible playbook. This script applies the configuration intents to the fabric, setting up the network as specified in the intent files.


```bash
ansible-playbook -i inv -e intent_dir=/workspaces/srl-netbox-demo/intents/ansible_intents --diff intent-based-ansible-lab/playbooks/cf_fabric.yml
```

Post-deployment, verify the fabric-wide configuration using `fcli` commands from the [nornir-srl](https://github.com/srl-labs/nornir-srl) repository. To facilitate these verifications, you can set up an alias for quick access:

```bash
CLAB_TOPO=srl_netbox.yaml
alias fcli="docker run -t --network $(grep '^name:' $CLAB_TOPO | awk '{print $2}') --rm -v /etc/hosts:/etc/hosts:ro -v ${PWD}/${CLAB_TOPO}:/topo.yml ghcr.io/srl-labs/nornir-srl:latest -t /topo.yml"
```

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
