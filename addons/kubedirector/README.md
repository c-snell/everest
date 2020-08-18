Instructions for building kubedirector image and integrating with hcp

# STEP 1
* Make changes to Dockerfile to include any additional packages
* Add any templates files that will be required to bootstrap the application
* Modify install, reconfig and rollback functions in startscript
  - For Helm based applications, modify hpecp-bootstrap-kubedirector configmap in hpecp-bootstrap to include
  values.yaml
  - Change install funtion to use helm install function to install the helm chart
  - Change rollback function to use helm uninstall function
* Build and upload the image

Use build.sh and push.sh to build and push the images. It will use
VERSION file for image version.

For debugging
deploy.sh, rollback.sh, reconfigure.sh and teardown.sh scripts can be used to test the deployment

hpecp-bootstrap-kubedirector configmap can be used for performing any reconfiguration.


# STEP 2
* Create an addon section for the kubedirector in k8s_manifest.json file
* It also has to be included in the list of versions that will be supported
* Use the following as an example. required, system and order must be carefully defined.
  If order is not specified, it will be deployed after all ordered ones are deployed
```
kubedirector:
    required: false
    version: "unstable"
    system: false
    order: 1000
    deployment: hpecp-bootstrap-kubedirector.yaml
    label:
      name: "kubedirector"
      description: "kubedirector deployment"
```

# STEP 3
Create a symlink of the file hpecp-bootstrap-kubedirector.yaml under <EVEREST_REPO>/install/k8s-addons/
(cd ../../install/k8s-addons; ln -s ../../kubernetes/addons/hpecp-bootstrap-kubedirector.yaml hpecp-bootstrap-kubedirector.yaml)

# STEP 4
Building a new hcp bin file should pick up the new deployment yaml (hpecp-bootstrap-kubedirector.yaml)
