# Zitadel Console Unreachable via External Gateway
* **Date:** 9th July, 2026

## Description
After ExternalDNS created a subdomain (`iam.niovial.io`) pointing to Zitadel's console UI, all connectivity attempts to the domain failed. The external Gateway (backed by a Hetzner Load Balancer via `hcloud-ccm`) showed no errors, and Zitadel's pods were healthy.

## Investigation
The following were checked during debugging (in no particular order):

* Gateway status
* K8s events
* Pod health

None of the above revealed anything. Backtracking to the Terraform-managed load balancer config (set via `hcloud-ccm`), I compared it against the `hcloud-k8s` Terraform module I had used as a reference. That module enabled proxy protocol both on the Hetzner load balancer (via `hcloud-ccm`) and on Cilium. My config only had it enabled on the load balancer side.

Proxy protocol prepends a header to forwarded packets so the receiving end knows the original client's source IP. Cilium drops any packet carrying this header unless it has been explicitly configured to expect it (`enableProxyProtocol`). Since only the load balancer was sending the header, and Cilium wasn't told to expect it, all incoming packets were being silently dropped.

## Resolution
Set `enableProxyProtocol` to `true` on Cilium's Gateway API configuration to match the load balancer, so that Cilium correctly parses and strips the proxy protocol header instead of dropping the packet.