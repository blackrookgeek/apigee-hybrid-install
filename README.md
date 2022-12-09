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
This update represents a significant change in approach to the organization of features that are supported by the default scripts. Conceptually, this update breaks apart Configuration from Deployment related activities.

Configuration includes:
 - Defining and customizing manifests
 - Optionally, creating Organization level assets, such as Service Accounts, on the Control Plane

Deployment includes:
 - Applying Apigee to a specific cluster
 - Updating Apigee on a specific cluster
 - Removing Apigee from a cluster
 - *All actions apply or execute the configurations defined during Configuration*

The separation allows Operations teams to define and review the Apigee configuration before applying it to a cluster. It also simplifies the application of Apigee from within a deployment pipeline as all Configuration activities are performed before the pipeline is triggered and only Deployment steps need to run from within the pipeline.

The Prerequisites and Permissions needed to perform Configuration vs Deployment follow:

|  | Prerequisites | Permissions</br>(User or Pipeline) |
| - | - | - |
| Configuration | **Standard**: jq, envsubst, sed</br>**Service Accounts**: gcloud</br>**Demo config**: jq, envsubst, sed, curl, gcloud | **Standard**: none</br>**Service Accounts**: GCP Service Account Admin</br>**Demo Config**: Org Admin |
| Deployment | kubectl | GCP: none</br>k8s: cluster admin |


### Configuring the manifests
apigee-hybrid-setup.sh

USAGE: **apigee-hybrid-setup.sh [attributes] [types] [flags]**

Helps create the Kubernetes manifests needed to deploy and manage Apigee Hybrid. This setup script is focused on the management of the manifest files. For deploying Apigee Hybrid to a k8s cluster, *please use the companion apigee-hyrid-deploy.sh script*.

REQUIRED attributes (varies by Command):

    --org             <ORGANIZATION_NAME>           Set the Apigee Organization.
                                                    If not set, the project configured in gcloud will be used.
    --env             <ENVIRONMENT_NAME>            Set the Apigee Environment.
                                                    If not set, a random environment within the organization will be selected.
    --envgroup        <ENVIRONMENT_GROUP_NAME>      Set the Apigee Environment Group.
                                                    If not set, a random environment group within the organization will be selected.
    --ingress-domain  <ENVIRONMENT_GROUP_HOSTNAME>  Set the hostname. This will be
                                                    used to generate self signed certificates.
    --namespace       <APIGEE_NAMESPACE>            The name of the namespace where
                                                    apigee components will be installed. Defaults to "apigee".
    --cluster-name    <CLUSTER_NAME>                The Kubernetes cluster name.
    --cluster-region  <CLUSTER_REGION>              The region in which the
                                                    Kubernetes cluster resides.
    --gcp-project-id  <GCP_PROJECT_ID>              The GCP Project ID where the
                                                    Kubernetes cluster exists. This can be different from the Apigee Organization name.

Specifies the resource types to be acted upon (at least one is REQUIRED):

    --configure-directory-names  Rename the instance, environment and environment group
                                 directories to their correct names.
    --fill-values                Replace the values for organization, environment, etc.
                                 in the kubernetes yaml files.
    --add-ingress-tls-cert       Add Certificate resource which will generate
                                 a self signed TLS cert for the provided --ingress-domain
    --configure-all              Used to execute all the tasks that can be performed
                                 by the script.
                                 *NOTE*: does not include --enable-openshift-scc
    --enable-openshift-scc       Indicates that the cluster is on OpenShift and will enable scc configurations.
    --demo-autoconfiguration     Auto configures with a Single EnvironmentGroup & Environment reading information from the Apigee Organization (Mgmt Plane) and creating and configuring a non-prod Service Account
                                 NOTEs:
                                   1) curl is required
                                   2) the user executing --demo-autoconfiguration must have a
                                 valid GCP account and gcloud installed and configured
    --verbose                    Show detailed output for debugging.
    --version                    Display version of apigee hybrid setup.
    --help                       Display usage information.

EXAMPLES:

Setup everything:

      ./apigee-hybrid-setup.sh \
         --org my-organization-name \
         --env dev01 \
         --envgroup dev-environments \
         --add-ingress-tls-cert dev.mycompany.com \
         --namespace apigee \
         --cluster-name apigee-hybrid-cluster \
         --cluster-region us-west1 \
         --configure-all

Configure a basic demo configuration for Hybrid
pulling information from the control plane:

      ./apigee-hybrid-setup.sh \
         --org my-organization-name \
         --demo-autoconfiguration


### Creating Service Accounts
Usage: create-service-account.sh

Flags:

      -e / --env         Environment. prod/non-prod. 
      -p / --profile     Profile name. Should be accompanied by --env prod.
      -d / --dir         Target directory for service account.
      -i / --project-id  GCP project ID. Defaults to the project ID configured in gcloud.
      -n / --name        Name of the service account.
      -h / --help        Help menu.

**List of Supported profiles**: 
apigee-logger apigee-metrics apigee-cassandra apigee-udca apigee-synchronizer apigee-mart apigee-watcher apigee-runtime 


### Deploying the manifests

apigee-hybrid-deploy.sh

USAGE: 
**apigee-hybrid-deploy.sh [command] [attributes] [types] [flags]**

Provides a prescriptive approach to installing Apigee. Use this script in combination with apigee-hybrid-setup.sh. The setup script is used to pre-configure the runtimes for the Organization. This deployment script will deploy a configured runtime into kubernetes.

Available commands:

    apply             one of REQUIRED               Specifies that a deployment operation 
                                                    will be performed
    delete            one of REQUIRED               Deletes Apigee Hybrid from the Cluster 
                                                    Note 1: Only "--all" is supported
                                                    Note 2: Known Issue, Apigee:Iss12
                                                    namespace sometimes does not delete
    get               one of REQUIRED               Dumps a full list of everything in
                                                    the namespace

REQUIRED attributes (varies by Command):

    --org             <ORGANIZATION_NAME>           Set the Apigee Organization.
    --env             <ENVIRONMENT_NAME>            Set the Apigee Environment.
                                                    If not set, all configured
                                                    environments will be deployed.
    --envgroup        <ENVIRONMENT_GROUP_NAME>      Set the Apigee Environment Group.
                                                    If not set, all configured
                                                    ingresses will be deployed.
    --namespace       <APIGEE_NAMESPACE>            The name of the namespace where
                                                    apigee components will be installed.
                                                    Defaults to "apigee".
    --cluster-name    <CLUSTER_NAME>                The Kubernetes cluster name.
    --cluster-region  <CLUSTER_REGION>              The region in which the
                                                    Kubernetes cluster resides.

Specifies the resource types to be acted upon (at least one is REQUIRED):

    --gcp-sa-and-secrets   (apply)              Deploy GCP service account(s) into 
                                                corresponding secret(s) containing 
                                                the keys in the kubernetes cluster.
    --runtime-components   (apply)              Deploy all Apigee components and 
                                                resources in the correct order.
    --all                  (apply|delete|get)   Used to execute all the tasks that 
                                                can be performed for the Command selected.

Optional flags:

    --verbose                    Show detailed output for debugging.
    --version                    Display version of Apigee Hybrid that will be deployed.
                                 NOTE: install script does not support setting 
                                 or changing the install version.
    --help                       Display usage information.

EXAMPLES:

Apply everything:
    
      ./apigee-hybrid-deploy.sh apply \
         --org business-org \
         --env development \
         --envgroup external-consumers \
         --namespace apigee \
         --cluster-name apigee-hybrid-west \
         --cluster-region us-west1 \
         --all
    
Only Apply service accounts and enable verbose logging:

      ./apigee-hybrid-deploy.sh apply \
         --org business-org \
         --env development \
         --envgroup external-consumers \
         --namespace apigee \
         --cluster-name apigee-hybrid-west \
         --cluster-region us-west1 \
         --gcp-sa-and-secrets \
         --verbose

