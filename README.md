Datapower  Rollback Guide
This document provides step-by-step instructions for rollback Datapower service using pipeline.
Rollback  to dev ,QUA or UAT


Navigate to:
Builds → Select feature/develop,qua or uat branch → Run Pipeline


give the details like---
RELEASE_NAME- for dev- dev-datapwer, for qua- qua-datapower, for uat- uat-datapower
REVISION_NUMBER--- you can get this info from deployment-info/dev/helm_history_dev-datapower.txt(respectively in  qua or uat)
Sample Content:


REVISION	UPDATED                 	STATUS    	CHART               	APP VERSION	DESCRIPTION
32      	Thu Oct 23 12:40:57 2025	superseded	datapowerchart-0.1.0	1.16.0     	Upgrade complete
33      	Thu Oct 30 12:35:43 2025	superseded	datapowerchart-0.1.0	1.16.0     	Upgrade complete
34      	Thu Nov  6 13:50:50 2025	deployed  	datapowerchart-0.1.0	1.16.0     	Upgrade complete
NAMESPACE_NAME--- you have to provide the namespace name of datapower service(dp-dev,dp-qua,dp-uat)
after giving this info it will be rollbacked to previous version























*Datapower Deployment Guide*

This document provides step-by-step instructions for deploying Datapower deployment using pipeline.

1. Prerequisites
Configuration Files
For new application deployments, configuration files must be added under the configuration/ directory.
The structure should include environment-specific folders:
configuration/
├── dev/
├── qua/
└── uat/

2. user-input Variables
Each application folder must contain a file named user-vars.env that defines environment-specific variables for your application.
Example:
#dev-
ENV=dev
NAMESPACE=dp-qua
SERVICE=dp-qua
DOMAIN=qua
Helm_Release=1.0
RELEASE_NAME=qua-datapower
CONFIG_FILE=../Configuration/qua/cfg/destination.cfg
LOCAL_FILE=../Configuration/qua/local/dev/
CERT_FILE="../Configuration/qua/cert/dp-dev.apps.eipdev.resbank.co.za-privkey.pem,../Configuration/qua/cert/EIP_DPPrivateKey.pem,../Configuration/qua/cert/IssuingCA.crt,../Configuration/qua/cert/PolicyCA.crt,../Configuration/qua/cert/RootCA.crt,../Configuration/qua/cert/SARS_Public_2025.cer,../Configuration/qua/cert/dp-dev.apps.eipdev.resbank.co.za.pem"

#uat-
ENV=uat
NAMESPACE=dp-uat
SERVICE=dp-uat
DOMAIN=uat
Helm_Release=1.0
RELEASE_NAME=uat-datapower
CONFIG_FILE=../Configuration/uat/cfg/destination.cfg
LOCAL_FILE=../Configuration/uat/local/uat/
CERT_FILE="../Configuration/uat/cert/dp-dev.apps.eipdev.resbank.co.za-privkey.pem,../Configuration/uat/cert/EIP_DPPrivateKey.pem,../Configuration/uat/cert/IssuingCA.crt,../Configuration/uat/cert/PolicyCA.crt,../Configuration/uat/cert/RootCA.crt,../Configuration/uat/cert/SARS_Public_2025.cer,../Configuration/uat/cert/dp-dev.apps.eipdev.resbank.co.za.pem"

#qua-
ENV=qua
NAMESPACE=dp-qua
SERVICE=dp-qua
DOMAIN=qua
Helm_Release=1.0
RELEASE_NAME=qua-datapower
CONFIG_FILE=../Configuration/qua/cfg/destination.cfg
LOCAL_FILE=../Configuration/qua/local/qua/
CERT_FILE="../Configuration/qua/cert/dp-dev.apps.eipdev.resbank.co.za-privkey.pem,../Configuration/qua/cert/EIP_DPPrivateKey.pem,../Configuration/qua/cert/IssuingCA.crt,../Configuration/qua/cert/PolicyCA.crt,../Configuration/qua/cert/RootCA.crt,../Configuration/qua/cert/SARS_Public_2025.cer,../Configuration/qua/cert/dp-dev.apps.eipdev.resbank.co.za.pem"


3. Pipeline Variable Configuration:

When adding a new runtime configuration, ensure that the runtime name is also added to the RUNTIME variable in the .gitlab-ci.yml file.
Example Snippet:
variables:
  RUNTIME:
    value: "Select Runtime To Deploy"
    options:
      - "Select Runtime To Deploy"
      - "utilities"
      - "add here"

Note:
Replace "add here" with the new runtime name corresponding to your application.
This ensures the new runtime appears as a selectable option when running the pipeline in GitLab.

*Deployment Steps*
1. Trigger the Pipeline


Navigate to:
Builds → Pipeline → Choose the branch you want to deploy → Select runtime → Run

The application code will be cloned from the same branch of the application repository.

2. Build Process

Once triggered, the build process starts and executes the following *stages* for dev:

Pipeline Stages
  - deploy_dev
  - deploy_uat
  - deploy_qua
  - generate-rollback-info-dev
  - generate-rollback-info-qua
  - generate-rollback-info-uat



3. prepare-configuration-dev:

in this step configmap and secret will be created using configuration file provided by developer and value.yaml will be created wich will be used in next step to add these configmaps and secret in the service using helm



4. deploy_dev:

At the end of the pipeline:
configmaps and secret in the service are deployed using helm

5. Rollback Information

After deployment, a rollback info file is generated and pushed to the same repository.

Example:

deployment-info/dev/helm_history_dev-datapower.txt

Sample Content:

REVISION	UPDATED                 	STATUS    	CHART               	APP VERSION	DESCRIPTION                                                                                                                                                                                                          
32      	Thu Oct 23 12:40:57 2025	superseded	datapowerchart-0.1.0	1.16.0     	Upgrade complete                                                                                                                                                                                                                    
33      	Thu Oct 30 12:35:43 2025	superseded	datapowerchart-0.1.0	1.16.0     	Upgrade complete                                                                                                                                                                                                                    
34      	Thu Nov  6 13:50:50 2025	deployed  	datapowerchart-0.1.0	1.16.0     	Upgrade complete                                                                                                                                                                                                                    


*Deploying to QUA or UAT*

1. Navigate to:
Builds → Select qua or uat branch → Run Pipeline 

2. Select the runtime and paste the Image Tag obtained from the DEV pipeline.

same steps like dev will be followed.

3. A new rollback file is automatically generated in the same qua or uat branch:

This file contains deployment details for the respective environment.
