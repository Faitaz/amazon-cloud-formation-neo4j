#!/bin/bash

STACK_NAME=$1

TEMPLATE_BODY="file://neo4j.template.yaml"
REGION=`aws configure get region`

Password="foo123"
KeyName="neo4j-${REGION}"
SSHCIDR="0.0.0.0/0"
NodeCount="3"
GraphDataScienceVersion="None"

aws cloudformation create-stack \
--capabilities CAPABILITY_IAM \
--stack-name ${STACK_NAME} \
--template-body ${TEMPLATE_BODY} \
--region ${REGION} \
--parameters \
ParameterKey=Password,ParameterValue=${Password} \
ParameterKey=KeyName,ParameterValue=${KeyName} \
ParameterKey=SSHCIDR,ParameterValue=${SSHCIDR} \
ParameterKey=NodeCount,ParameterValue=${NodeCount} \
ParameterKey=GraphDataScienceVersion,ParameterValue=${GraphDataScienceVersion} \
ParameterKey=LicenseKey,ParameterValue="None"