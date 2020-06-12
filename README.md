# Managing test CA certificates for DPS and IoT Hub

## WARNING

Certificates created by these scripts **MUST NOT** be used for production.  They contain hard-coded passwords ("P@ssw0rd"), expire after 30 days, and most importantly are provided for demonstration purposes to help you quickly understand CA Certificates.  When productizing against CA Certificates, you'll need to use your own security best practices for certification creation and lifetime management.

## Introduction

This document helps create certificates for use in **pre-testing** IoT SDK's against the DPS and IoT Hub.  In particular, the tools in this directory can be used to either setup CA Certificates (along with proof of possession) or Edge device certificates.  This document assumes you have basic familiarity with the scenario you are setting up for as well as some knowledge of Bash.

This directory contains a Bash script to help create **test** certificates for Azure IoT Hub's CA Certificate / proof-of-possession and/or Edge certificates.

A more detailed document showing UI screen shots for CA Certificates and proof of possession flow is available from [the official documentation].

A more detailed document explaining Edge and showing its use of certificates generated here is available from the [Edge gateway creation documentation].

Before you continue with generation of certificates you need to initialize directory structure.
* Run `./certGen.sh init`

## Create the certificate chain

First you need to create a CA and an intermediate certificate signer that chains back to the CA.

* Run `./certGen.sh create_root_certificate relayr`
* Run `./certGen.sh create_intermediate_certificate relayrIntermediate relayr`

## Proof of Possession

*Optional - Only perform this step if you're setting up CA Certificates and proof of possession.  For simple device certificates, such as Edge certificates, skip to the next step.*

Now that you've registered your root CA with Azure IoT Hub, you'll need to prove that you actually own it.

Select the new certificate that you've created and navigate to and select  "Generate Verification Code".  This will give you a verification string you will need to place as the subject name of a certificate that you need to sign.  For our example, assume IoT Hub verification code was "106A5SD242AF512B3498BD6098C4941E66R34H268DDB3288", the certificate subject name should be that code.

* Run `./certGen.sh create_verification_certificate 106A5SD242AF512B3498BD6098C4941E66R34H268DDB3288 relayr`

In both cases, the scripts will output the name of the file containing `"CN=106A5SD242AF512B3498BD6098C4941E66R34H268DDB3288"` to the console.  Upload this file to IoT Hub (in the same UX that had the "Generate Verification Code") and select "Verify".

## Create a device certificate

### IoT Leaf Device

* Run `./certGen.sh create_device_certificate mydevice relayrIntermediate` to create the new device certificate.  
  This will create the files ./certs/device/mydevice.cert.pem that contain the public key and ./private/device/mydevice.key.pem that contains the device's private key.  

* `cd ./certs && cat device/mydevice.cert.pem relayrIntermediate.ca.cert.pem relayr.ca.cert.pem > device/mydevice-full-chain.cert.pem` to get the public key.

### IoT Edge Device

* Run `./certGen.sh create_edge_device_certificate myEdgeDevice relayrIntermediate` to create the new IoT Edge device certificate.  
  This will create the files ./certs/device/myEdgeDevice.cert.pem that contain the public key and ./private/device/myEdgeDevice.key.pem that contains the Edge device's private key.  
* `cd ./certs && cat device/myEdgeDevice.cert.pem relayrIntermediate.ca.cert.pem relayr.ca.cert.pem > device/myEdgeDevice-full-chain.cert.pem` to get the public key.

## Store certificate in Azure Key Vault

Run `openssl pkcs8 -topk8 -in private/relayr.ca.key.pem -nocrypt > relayr.ca.bundle.pem && cat certs/relayr.ca.cert.pem >> relayr.ca.bundle.pem` to create a bundle containing private key and X.509 certificate in PEM format.

To import it into Key Vault run `az keyvault certificate import --vault-name relayr-key-vault --file relayr.ca.bundle.pem  --name 'relayrCA'`.

[the official documentation]: https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-security-x509-get-started
[Edge gateway creation documentation]: https://docs.microsoft.com/en-us/azure/iot-edge/how-to-create-gateway-device
