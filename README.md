# Google's formal Documentation

## Hybrid Installation
Follow this [Installation Guide](https://cloud.google.com/apigee/docs/hybrid/preview/new-install-user-guide)

# 
---



# Customizations and Updates that have been submitted through PRs to Google
 - [Forward Proxy updates](#forward-proxy-updates)
 - [Add gitignore](#add-gitignore)
 - [Removed kpt dependency](#removed-kpt-dependency)
 - [Configured automount SA on controller](#configured-automount-sa-on-controller)
 - [Install Script Config and Deploy separation](#install-script-config-and-deploy-separation)


---
## Forward Proxy updates
A forward proxy server may be configured for connecting to the Control Plane and/or for sounthbound calls from the runtime to a target API.

[Related Pull Request](https://github.com/apigee/apigee-hybrid-install/pull/16)


### `Control Plane`

#### Available in:

 - `overlays/controllers/apigee-controller`
 - `overlays/instances/{INSTANCE_NAME}/datastore`
 - `overlays/instances/{INSTANCE_NAME}/environments/{ENV_NAME}`
 - `overlays/instances/{INSTANCE_NAME}/organization`
 - `overlays/instances/{INSTANCE_NAME}/telemetry`

#### Enabling:
Uncomment the component reference "`- ./components/control-plane-http-proxy/`" in the respective `kustomization.yaml` files in each folder.

### `Runtime -> Target`

#### Available in:

 - `overlays/instances/{INSTANCE_NAME}/environments/{ENV_NAME}`

#### Enabling:
Uncomment the component reference "`- ./components/runtime-egress-http-proxy/`" in `apigee-environment.yaml`.


### Modifications to be made:
Pay close attention to each patch file. Not all components accept the same mix of parameters currently. Additionally, the password may need to be base64 encoded.

Example patch file:
- components/control-plane-http-proxy/patch.yaml
   -     `scheme`: *REQUIRED* One of `HTTP` or `HTTPS`
   -     `host`: *REQUIRED* The Host address of your proxy
   -     `port`: *REQUIRED* The port number
   -     `username`: *OPTIONAL* The username associated with your proxy
   -     `password`: *OPTIONAL* The password for accessing the proxy

### Usage:

1. If you have not yet installed Apigee Hybrid, you can continue with the installation steps and these changes will get applied in the process
1. If you already have Apigee Hybrid installed, you will need to apply these new changes using:

```
kubectl apply -k overlays/controllers/apigee-controller
kubectl apply -k overlays/instances/{INSTANCE_NAME}
```

---
## Add gitignore
Added .gitignore ignoring:
 - /service-accounts **Note:** This may need to be changed if using a Pipeline where the service account keys need to be committed (**not recommended**)

---
## Removed kpt dependency
A forward proxy server may be configured for connecting to the Control Plane and/or for sounthbound calls from the runtime to a target API.

[Related Pull Request](https://github.com/apigee/apigee-hybrid-install/pull/21)

### Updated dependencies
kpt is no longer needed for the install script.

**Note:** "# kpt-set:" is still used as a placeholder in the yaml manifests. 

---
## Configured automount SA on controller
When automount default service account is disabled in k8s, the controller would throw an error. Updated configuration to force the automounting of the default SA.

[Related Pull Request](https://github.com/apigee/apigee-hybrid-install/pull/22)


---
## Install Script Config and Deploy separation
A significant change to the install script has been made. The Configuration (pre-install) and Deployment (install into a cluster) has been separated into two scripts
 - apigee-hybrid-setup.sh
 - apigee-hybrid-deploy.sh

[Related Pull Request](https://github.com/apigee/apigee-hybrid-install/pull/28)

### Overall approach / guide
This update represents a significant change in approach to the organization of features that are supported by the default scripts. Conceptually, this update breaks apart Configuration related activities from Deployment activities.

Configuration includes:
 - Defining the manifests
 - Optionally creating Organization level assets, such as Service Accounts, on the Control Plane

Deployment includes:
 - Applying Apigee to a specific cluster
 - Updating Apigee on a specific cluster
 - Removing Apigee from a cluster
 - All actions apply or execute the configurations defined during Configuration

This approach allows Operations teams to define and review their Apigee configuration before applying it to a cluster. It also simplifies the application of Apigee from within a deployment pipeline as all Configuration activities are performed before the pipeline is triggered and only deployment steps need to run from within the pipeline.

The Prerequisites and Permissions needed to perform Configuration vs Deployment are also different:

|  | Prerequisites | Permissions |
| - | - | - |
| Configuration | Title | Title |
| Deployment | Text | Text |


### Configuring the manifests

### Deploying the manifests


