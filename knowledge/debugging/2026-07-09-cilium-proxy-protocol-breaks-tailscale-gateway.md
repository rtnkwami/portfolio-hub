# Cilium Proxy Protocol Enforcement Breaks Tailscale Gateway

* **Date:** 9th July, 2026

## Description
After setting `enableProxyProtocol` to `true` on Cilium to resolve a [previous issue](/knowledge/2026-07-09-zitadel-console-unreachable-external-gateway.md), traffic to my [Management Gateway](/k8s/app-of-apps/infra/configuration/networking/gateways/tailscale-gateway.yaml) for north-south traffic on my private tailnet began to be dropped. This broke access to ArgoCD and Grafana over Tailscale, both exposed via HTTPRoutes attached to that Gateway.

## Investigation
Cilium's proxy protocol setting is global; it applies to all Gateways, not just the one behind the Hetzner load balancer. The Tailscale operator's Gateway does not add a proxy protocol header on forwarded packets, so once Cilium was configured to expect one, it began dropping all traffic arriving through the Tailscale Gateway as well.

Cilium currently has no per-Gateway option to enable or disable proxy protocol; the setting is all-or-nothing across every Gateway in the cluster. Further research confirmed that the Tailscale operator does not support adding proxy protocol to forwarded traffic, and there is no declarative way to enable it, only an imperative option via the tailscale CLI, which I rejected as it doesn't fit GitOps.

## Resolution
Installed Envoy Gateway and reconfigured the Tailscale Gateway to run on it instead of under Cilium's Gateway API implementation. This bypasses Cilium's global proxy protocol enforcement for that Gateway specifically, since Envoy Gateway is a separate Gateway API implementation unaffected by Cilium's `enableProxyProtocol` setting. 

Access to ArgoCD and Grafana over the private tailnet was restored.

## Edit: 4th August, 2025

Upon further reflection, I decided to let go of an additional Gateway API component, as I did not want to have yet another tool to maintain in my cluster. The only reason why I wanted to create a private gateway for services in my cluster to be exposed over my tailnet was to use user-friendly names such as `argocd.internal.example.com`.

To me that isn't a justifiable reason to introduce Envoy Gateway into the cluster. As such I decided to drop Envoy Gateway from my cluster, and stick to exposing private services over my tailnet, using a configured proxy group for tailnet services.