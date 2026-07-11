# VictoriaMetrics Hangs Forever During Cluster Deletion

* **Date:** 8th July, 2026

## Description
The homelab k8s cluster hangs forever when the root ArgoCD app (for app-of-apps) is deleted. Since it is one of the last infrastructure components to be deployed (last sync wave), it is also the first to be destroyed. However, due to hanging forever, all other infrastructure components are also prevented from being deleted, leaving ArgoCD hanging and unable to delete resources.

## Investigation
The following in-cluster resources were checked during debugging (in no particular order):

* VictoriaMetrics Operator logs
* ArgoCD sync logs
* K8s cluster events

Investigation into the above yielded no results. However, a Google search into the issue revealed that the `victoria-metrics-k8s-stack` helm chart does not guarantee the ordering of resources within the chart.

During the installation of the chart, the `victoria-metrics-operator` chart is pulled in and installed. It installs the CRDs for the entire `victoria-metrics-k8s-stack` helm chart, but also places the finalizer `apps.victoriametrics.com/finalizer` on the custom resources in the `victoria-metrics-k8s-stack` helm chart.

During deletion, there is a very real possibility of the operator being deleted before other resources in the `victoria-metrics-k8s-stack` helm chart due to there being no ordering guarantees for resources within the chart. Since the operator is responsible for removing the `apps.victoriametrics.com/finalizer` finalizer, and it is no longer available, since it was deleted, the finalizer stays on the custom resources forever, preventing ArgoCD from deleting them.

## Resolution
The following steps were taken together to fix the issue:

* Deploy the `victoria-metrics-operator` helm chart separately from the `victoria-metrics-k8s-stack` helm chart. Make sure you disable the operator within the the `victoria-metrics-k8s-stack` helm chart.

* Deploy the operator in a different namespace from the `victoria-metrics-k8s-stack` helm chart.

* Set up ArgoCD sync waves to deploy the operator **before** the `victoria-metrics-k8s-stack` helm chart is deployed.
