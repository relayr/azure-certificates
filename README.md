# Managing test CA certificates for samples and tutorials

## WARNING

Certificates created by these scripts **MUST NOT** be used for production.  They contain hard-coded passwords ("P@ssw0rd"), expire after 30 days, and most importantly are provided for demonstration purposes to help you quickly understand CA Certificates.  When productizing against CA Certificates, you'll need to use your own security best practices for certification creation and lifetime management.

## Introduction

This document helps create certificates for use in **pre-testing** IoT SDK's against the IoT Hub.  In particular, the tools in this directory can be used to either setup CA Certificates (along with proof of possession) or Edge device certificates.  This document assumes you have basic familiarity with the scenario you are setting up for as well as some knowledge of Bash.

This directory contains a Bash script to help create **test** certificates for Azure IoT Hub's CA Certificate / proof-of-possession and/or Edge certificates.

A more detailed document showing UI screen shots for CA Certificates and proof of possession flow is available from [the official documentation].

A more detailed document explaining Edge and showing its use of certificates generated here is available from the [Edge gateway creation documentation].

## USE

## Step 1 - Initial Setup

You'll need to do some initial setup prior to running these scripts.

* `cd` to the directory you want to run in.  All files will be created as children of this directory.
* `cp *.cnf` and `cp *.sh` from the directory this .MD file is located into your working directory.
* `chmod 700 certGen.sh`

## Step 2 - Create the certificate chain

First you need to create a CA and an intermediate certificate signer that chains back to the CA.

* Run `./certGen.sh create_root_and_intermediate`

## Step 3 - Proof of Possession

*Optional - Only perform this step if you're setting up CA Certificates and proof of possession.  For simple device certificates, such as Edge certificates, skip to the next step.*

Now that you've registered your root CA with Azure IoT Hub, you'll need to prove that you actually own it.

Select the new certificate that you've created and navigate to and select  "Generate Verification Code".  This will give you a verification string you will need to place as the subject name of a certificate that you need to sign.  For our example, assume IoT Hub verification code was "106A5SD242AF512B3498BD6098C4941E66R34H268DDB3288", the certificate subject name should be that code.

* Run `./certGen.sh create_verification_certificate 106A5SD242AF512B3498BD6098C4941E66R34H268DDB3288`

In both cases, the scripts will output the name of the file containing `"CN=106A5SD242AF512B3498BD6098C4941E66R34H268DDB3288"` to the console.  Upload this file to IoT Hub (in the same UX that had the "Generate Verification Code") and select "Verify".

## Step 4 - Create a new device

Finally, let's create an application and corresponding device on IoT Hub that shows how CA Certificates are used.

On Azure IoT Hub, navigate to the IoT Devices section, or launch Azure IoT Explorer.  Add a new device (e.g. `mydevice`), and for its authentication type chose "X.509 CA Signed".  Devices can authenticate to IoT Hub using a certificate that is signed by the Root CA from Step 2.

#### IoT Leaf Device

* Run `./certGen.sh create_device_certificate mydevice` to create the new device certificate.  
  This will create the files ./certs/device/mydevice.cert.pem that contain the public key and ./private/device/mydevice.key.pem that contains the device's private key.  

* `cd ./certs && cat device/mydevice.cert.pem relayr-test-only.intermediate.cert.pem relayr-test-only.root.ca.cert.pem > device/mydevice-full-chain.cert.pem` to get the public key.

#### IoT Edge Device

* Run `./certGen.sh create_edge_device_certificate myEdgeDevice` to create the new IoT Edge device certificate.  
  This will create the files ./certs/device/myEdgeDevice.cert.pem that contain the public key and ./private/device/myEdgeDevice.key.pem that contains the Edge device's private key.  
* `cd ./certs && cat device/myEdgeDevice.cert.pem relayr-test-only.intermediate.cert.pem relayr-test-only.root.ca.cert.pem > device/myEdgeDevice-full-chain.cert.pem` to get the public key.

[the official documentation]: https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-security-x509-get-started
[Edge gateway creation documentation]: https://docs.microsoft.com/en-us/azure/iot-edge/how-to-create-gateway-device
