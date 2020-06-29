#!/bin/bash

## Copyright (c) Microsoft. All rights reserved.
## Licensed under the MIT license. See LICENSE file in the project root for full license information.

###############################################################################
# This script demonstrates creating X.509 certificates for an Azure IoT Hub
# CA Cert deployment.
#
# These certs MUST NOT be used in production.  It is expected that production
# certificates will be created using a company's proper secure signing process.
# These certs are intended only to help demonstrate and prototype CA certs.
###############################################################################

cert_dir="."
algorithm="genrsa"
key_bits_length="4096"
days_till_expire=100
openssl_config_file="./openssl.cnf"
ca_password="P@ssw0rd"

function makeCNsubject()
{
    local result="/CN=${1}"
    case $OSTYPE in
        msys|win32) result="/${result}"
    esac
    echo "$result"
}

function warn_certs_not_for_production()
{
    tput smso
    tput setaf 3
    echo "Certs generated by this script are not for production (e.g. they have hard-coded passwords of 'P@ssw0rd'."
    echo "This script is only to help you understand Azure IoT Hub CA Certificates."
    echo "Use your official, secure mechanisms for this cert generation."
    echo "Also note that these certs will expire in ${days_till_expire} days."
    tput sgr0
}

function generate_root_ca()
{
    local common_name=$1

    local password_cmd=" -aes256 -passout pass:${ca_password} "

    echo "Creating the Root CA Private Key"

    openssl ${algorithm} \
            ${password_cmd} \
            -out ${cert_dir}/private/${common_name}.ca.key.pem \
            ${key_bits_length}
    [ $? -eq 0 ] || exit $?
    chmod 400 ${cert_dir}/private/${common_name}.ca.key.pem
    [ $? -eq 0 ] || exit $?

    echo "Creating the Root CA Certificate"
    password_cmd=" -passin pass:${ca_password} "

    openssl req \
            -new \
            -x509 \
            -config ${openssl_config_file} \
            ${password_cmd} \
            -key ${cert_dir}/private/${common_name}.ca.key.pem \
            -subj "$(makeCNsubject "${common_name}")" \
            -days ${days_till_expire} \
            -sha256 \
            -extensions v3_ca \
            -out ${cert_dir}/certs/${common_name}.ca.cert.pem
    [ $? -eq 0 ] || exit $?
    cp ${cert_dir}/certs/${common_name}.ca.cert.pem ${cert_dir}/certs/${common_name}.chain.cert.pem
    [ $? -eq 0 ] || exit $?
    chmod 444 ${cert_dir}/certs/${common_name}.ca.cert.pem
    [ $? -eq 0 ] || exit $?

    echo "CA Root Certificate Generated At:"
    echo "---------------------------------"
    echo "    ${cert_dir}/certs/${common_name}.ca.cert.pem"
    echo ""
    openssl x509 -noout -text \
            -in ${cert_dir}/certs/${common_name}.ca.cert.pem

    warn_certs_not_for_production

    [ $? -eq 0 ] || exit $?
}



###############################################################################
# Generate Intermediate CA Cert
###############################################################################
function generate_intermediate_ca()
{
    local common_name=$1
    local ca_common_name=$2

    local password_cmd=" -aes256 -passout pass:${ca_password} "
    echo "Creating the Intermediate Device CA"
    echo "-----------------------------------"

    openssl ${algorithm} \
            ${password_cmd} \
            -out ${cert_dir}/private/${common_name}.ca.key.pem \
            ${key_bits_length}
    [ $? -eq 0 ] || exit $?
    chmod 400 ${cert_dir}/private/${common_name}.ca.key.pem
    [ $? -eq 0 ] || exit $?


    echo "Creating the Intermediate Device CA CSR"
    echo "-----------------------------------"
    password_cmd=" -passin pass:${ca_password} "

    openssl req -new -sha256 \
        ${password_cmd} \
        -config ${openssl_config_file} \
        -subj "$(makeCNsubject "${common_name}")" \
        -key ${cert_dir}/private/${common_name}.ca.key.pem \
        -out ${cert_dir}/csr/${common_name}.ca.csr.pem
    [ $? -eq 0 ] || exit $?

    echo "Signing the Intermediate Certificate with Root CA Cert"
    echo "-----------------------------------"
    password_cmd=" -passin pass:${ca_password} "

    openssl ca -batch \
        -config ${openssl_config_file} \
        ${password_cmd} \
        -extensions v3_intermediate_ca \
        -days ${days_till_expire} -notext -md sha256 \
        -keyfile ${cert_dir}/private/${ca_common_name}.ca.key.pem \
        -cert ${cert_dir}/certs/${ca_common_name}.ca.cert.pem \
        -in ${cert_dir}/csr/${common_name}.ca.csr.pem \
        -out ${cert_dir}/certs/${common_name}.ca.cert.pem
    [ $? -eq 0 ] || exit $?
    chmod 444 ${cert_dir}/certs/${common_name}.ca.cert.pem
    [ $? -eq 0 ] || exit $?

    echo "Verify signature of the Intermediate Device Certificate with Root CA"
    echo "-----------------------------------"
    openssl verify \
            -CAfile ${cert_dir}/certs/${ca_common_name}.chain.cert.pem \
            ${cert_dir}/certs/${common_name}.ca.cert.pem
    [ $? -eq 0 ] || exit $?

    echo "Intermediate CA Certificate Generated At:"
    echo "-----------------------------------------"
    echo "    ${cert_dir}/certs/${common_name}.ca.cert.pem"
    echo ""
    openssl x509 -noout -text \
            -in ${cert_dir}/certs/${common_name}.ca.cert.pem
    [ $? -eq 0 ] || exit $?

    echo "Create Root + Intermediate CA Chain Certificate"
    echo "-----------------------------------"
    cat ${cert_dir}/certs/${common_name}.ca.cert.pem \
        ${cert_dir}/certs/${ca_common_name}.chain.cert.pem > \
        ${cert_dir}/certs/${common_name}.chain.cert.pem
    [ $? -eq 0 ] || exit $?
    chmod 444 ${cert_dir}/certs/${common_name}.chain.cert.pem
    [ $? -eq 0 ] || exit $?

    echo "Root + Intermediate CA Chain Certificate Generated At:"
    echo "------------------------------------------------------"
    echo "    ${cert_dir}/certs/${common_name}.chain.cert.pem"

    warn_certs_not_for_production
}

###############################################################################
# Generate a Certificate for a device using specific openssl extension and
# signed with either the root or intermediate cert.
###############################################################################
function generate_device_certificate_common()
{
    local common_name="${1}"
    local device_prefix="${2}"
    local ca_prefix="${3}"
    local openssl_config_extension="${4}"
    local cert_type_diagnostic="${5}"

    local password_cmd=" -passin pass:${ca_password} "

    echo "Creating ${cert_type_diagnostic} Certificate"
    echo "----------------------------------------"

    openssl ${algorithm} \
            -out ${cert_dir}/private/${device_prefix}.key.pem \
            ${key_bits_length}
    [ $? -eq 0 ] || exit $?
    chmod 444 ${cert_dir}/private/${device_prefix}.key.pem
    [ $? -eq 0 ] || exit $?

    echo "Create the ${cert_type_diagnostic} Certificate Request"
    echo "----------------------------------------"
    openssl req -config ${openssl_config_file} \
        -key ${cert_dir}/private/${device_prefix}.key.pem \
        -subj "$(makeCNsubject "${common_name}")" \
        -new -sha256 -out ${cert_dir}/csr/${device_prefix}.csr.pem
    [ $? -eq 0 ] || exit $?

    openssl ca -batch -config ${openssl_config_file} \
            ${password_cmd} \
            -extensions "${openssl_config_extension}" \
            -days ${days_till_expire} -notext -md sha256 \
            -keyfile ${cert_dir}/private/${ca_prefix}.ca.key.pem \
            -cert ${cert_dir}/certs/${ca_prefix}.ca.cert.pem \
            -in ${cert_dir}/csr/${device_prefix}.csr.pem \
            -out ${cert_dir}/certs/${device_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?
    chmod 444 ${cert_dir}/certs/${device_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?

    echo "Verify signature of the ${cert_type_diagnostic}" \
         " certificate with the signer"
    echo "-----------------------------------"
    openssl verify \
            -CAfile ${cert_dir}/certs/${ca_prefix}.chain.cert.pem \
            ${cert_dir}/certs/${device_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?

    echo "${cert_type_diagnostic} Certificate Generated At:"
    echo "----------------------------------------"
    echo "    ${cert_dir}/certs/${device_prefix}.cert.pem"
    echo ""
    openssl x509 -noout -text \
            -in ${cert_dir}/certs/${device_prefix}.cert.pem
    [ $? -eq 0 ] || exit $?
}

###############################################################################
# Generate a certificate for a leaf device
# signed with either the root or intermediate cert.
###############################################################################
function generate_leaf_certificate()
{
    local common_name="${1}"
    local device_prefix="${2}"
    local ca_prefix="${3}"

    generate_device_certificate_common "${common_name}" "${device_prefix}" \
                                       "${ca_prefix}" \
                                       "usr_cert" \
                                       "Leaf Device"
}

###############################################################################
#  Creates required directories and removes left over cert files.
#  Run prior to creating Root CA; after that these files need to persist.
###############################################################################
function prepare_filesystem()
{
    if [ ! -f ${openssl_config_file} ]; then
        echo "Missing file ${openssl_config_file}"
        exit 1
    fi

    cd ${cert_dir}

    rm -rf csr
    rm -rf private
    rm -rf certs
    rm -rf intermediateCerts
    rm -rf newcerts

    mkdir -p csr
    mkdir -p private
    mkdir -p certs
    mkdir -p csr/device
    mkdir -p private/device
    mkdir -p certs/device
    mkdir -p intermediateCerts
    mkdir -p newcerts

    rm -f index.txt
    touch index.txt

    rm -f serial
    echo 01 > serial
}

###############################################################################
# Generates a certificate for verification, chained directly to the root.
###############################################################################
function generate_verification_certificate()
{
    if [ $# -ne 2 ]; then
        echo "Usage: <subjectName> <caSubjectName>"
        exit 1
    fi

    rm -f ${cert_dir}/private/verification-code.key.pem
    rm -f ${cert_dir}/certs/verification-code.cert.pem
    generate_leaf_certificate "${1}" "verification-code" \
                              "${2}"
}

###############################################################################
# Generates a certificate for a device, chained to the intermediate.
###############################################################################
function generate_device_certificate()
{
    if [ $# -ne 2 ]; then
        echo "Usage: <subjectName> <caSubjectName>"
        exit 1
    fi

    rm -f ${cert_dir}/private/device/$1.key.pem
    rm -f ${cert_dir}/certs/device/$1.key.pem
    rm -f ${cert_dir}/certs/device/$1-full-chain.cert.pem
    generate_leaf_certificate "${1}" "device/${1}" \
                              "${2}"
}

###############################################################################
# Generates a certificate for Edge device, chained to the intermediate.
###############################################################################
function generate_edge_device_certificate()
{
    if [ $# -ne 2 ]; then
        echo "Usage: <subjectName> <caSubjectName>"
        exit 1
    fi
    rm -f ${cert_dir}/private/device/$1.key.pem
    rm -f ${cert_dir}/certs/device/$1.cert.pem
    rm -f ${cert_dir}/certs/device/$1-full-chain.cert.pem

    # Note: Appending a '.ca' to the common name is useful in situations
    # where a user names their hostname as the edge device name.
    # By doing so we avoid TLS validation errors where we have a server or
    # client certificate where the hostname is used as the common name
    # which essentially results in "loop" for validation purposes.
    generate_device_certificate_common "${1}.ca" "device/${1}" \
                                        ${2} \
                                        "v3_intermediate_ca" "Edge Device"
}

if   [ "${1}" == "init" ]; then
    prepare_filesystem
elif [ "${1}" == "create_root_certificate" ]; then
    generate_root_ca "${2}"
elif [ "${1}" == "create_intermediate_certificate" ]; then
    generate_intermediate_ca "${2}" "${3}"
elif [ "${1}" == "create_verification_certificate" ]; then
    generate_verification_certificate "${2}" "${3}"
elif [ "${1}" == "create_device_certificate" ]; then
    generate_device_certificate "${2}" "${3}"
elif [ "${1}" == "create_edge_device_certificate" ]; then
    generate_edge_device_certificate "${2}" "${3}"
else
    echo "Usage: init                                                          # Initializes directory structure"
    echo "       create_root_certificate <subjectName>                         # Creates new root certificate"
    echo "       create_intermediate_certificate <subjectName> <caSubjectName> # Creates new intermediate certificate issued by some CA"
    echo "       create_verification_certificate <subjectName> <caSubjectName> # Creates a verification certificate, signed with <subjectName> and issued by some CA"
    echo "       create_device_certificate <subjectName> <caSubjectName>       # Creates a device certificate, signed with <subjectName> and issued by some CA"
    echo "       create_edge_device_certificate <subjectName> <caSubjectName>  # Creates an edge device certificate, signed with <subjectName> and issued by some CA"
    exit 1
fi

warn_certs_not_for_production
