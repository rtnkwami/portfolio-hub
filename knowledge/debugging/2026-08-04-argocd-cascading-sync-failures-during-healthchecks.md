# ArgoCD Application Sync Failures After Enabling Healthchecks

* **Date:** 4th August, 2026

## Description

I decided to have a folder of curated charts (`k8s/charts`) where I'd add helm charts that needed additional configuration and/or external services to work out of the box. 

One such chart in this folder was ZITADEL. It requires a PostgreSQL database to function properly, plus some secrets, such as its master key, among others. To ensure that installing the chart would be easier for me, I decided to create a curated chart for ZITADEL with all the necessary external resources.

In addition, I created a chart to configure the tools I needed to bootstrap a cluster into a state where workloads could be deployed. This chart is called `genesis` (the beginning, essentially of a cluster).

The next step was for me to create a single helm chart that would hold the configuration for both `zitadel` and `genesis`. This chart would allow for the app-of-apps pattern. In that chart, I set `genesis` with a lower sync wave than `zitadel` to ensure that `zitadel` would only be deployed once `genesis` was ready.

Ideally, this should have worked. However, I never knew that in ArgoCD v1.8, health checks for ArgoCD `Application` resources were removed, and that ArgoCD just waits for a few seconds before syncing Applications in different sync waves. That meant that as soon as `genesis` was synced (but not ready) `zitadel` would be synced as well. This caused issues where the CRDs `zitadel`'s chart depended on were not installed, causing the entire sync of the app-of-apps to fail and hang with several error messages.

## Investigation

To fix this issue, I read the argocd documentation on resource health, and then implemented a health check for applications (https://argo-cd.readthedocs.io/en/stable/operator-manual/health/).

This should have fixed the issue, however, I faced another issue. When I tore down and recreated the cluster, ArgoCD begain to fail sync waves. Several resources began to fail with errors such as: `unable to verify permissions`, and ArgoCD timing out when trying to reach `kube-apiserver`, which was strange to me, considering that RBAC wasn't touched at all in my configuration.

After some trial and error, I decided to to consult AI, which was a horrible decision considering I didn't really far before getting extremely annoyed by speculation. However, some good came out of it, in that I was pointed in a general direction that could be a possible issue: several Applications were deploying concurrently in the same sync wave.

So I decided to investigate. ArgoCD application controller logs weren't giving me many leads, so I decided rather to separate Applications into their own sync waves, and prevent concurrently applying resources.

## Resolution

It appeared that, when I enabled health checks, ArgoCD was evaluating the health of each resource in a currently executing sync wave. Since there were too many resources to check from different operators and controllers in the same sync wave, ArgoCD's application controller began to choke on the number of things it needed to check, and thus began to time out.

Separating resources into their own individual sync waves instead of concurrently applying a number of controllers all at the same time was the fix.

## Edit: 6th August, 2026

After further experimentation, I found that enabling application health checks for every single application was a bad idea. It caused ArgoCD to directly become overloaded again, since it was checking health for every single CRD on every single controller, plus every single resource in child applications, and all synchronously instead of asynchronously.

To ensure that healthchecks wouldn't choke ArgoCD anymore, I opted-out healthchecks from applications that were children of `genesis` while keeping healthchecks at the higher level where  `argocd`, `genesis` itself and `zitadel` were. That way sync waves + targeted health would gate application syncs correctly.

This resolved the choking issue immediately.
As an ending note, I went into the ArgoCD GitHub repository and found that they provide healthchecks for most of the custom resources I use in my clusters (e.g. cert-manager Certificate/CertificateRequests, GatewayAPI resources, etc.). As such, I didn't need to implement Lua scripts for any of these resources myself.