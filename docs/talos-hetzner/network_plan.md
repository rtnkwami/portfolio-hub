# Network Plan for Kubernetes Cluster on Hetzner Cloud

## Network Overview

* **Network CIDR Range:** 10.128.0.0/16
* **Total Host IP Addresses:** 65,534

* **CNI:** Cilium
* **Routing Mode:** Native (Hetzner native routing of pod IPs is being used)
* **IPAM:** Kubernetes (nodes are assigned CIDR ranges from a global podCIDR range for pods to use)

## Plan

### Nodes IPs

* **Potential Max Node Count:** 105
* **Theoretical Node IP Count:** 105
* **Minimum Required Network Size:** 128 IPs (/25 network)

* **Potential Max Control Plane Size:** 5 nodes
* **Potential Max Workers:** 100

#### Node Groups

* App (Stateless Nodes)
* Database (Stateful) Nodes -> Assume a smaller node count than App Nodes

### Kubernetes IPs

#### Pod CIDR

* Pod CIDR is driven by node count. Assuming each node has a /26 subnet, that is 64 IPs per node.

* Given the potential node count, we may assume a max limit for our nodes at **30 pods** per node.

* Excluding control plane:
  * Node Count * IPs -> 100 * 64 = ~6,400 IPs

Given total IPs, ideal podCIDR range -> 8,192 IPs (/19 network)

#### Services

* Given max theoretical limits, we may assume ~200 services at this scale

* Should each service be given an IP, total service IPs -> 200 * 1 = 200 IPs

* Minimum network size = 256 IPs (/24 network)

## Networks

* Node CIDR -> /25 (105 nodes) [105 IPs]
* Pod CIDR -> /19 (~6,400 pods) [~6,400 IPs]
* Service CIDR -> /24 (~200 services)

