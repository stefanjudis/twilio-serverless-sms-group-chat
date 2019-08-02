#!/bin/bash
set -e

if [ -z "$YOUR_NAME" ] || [ -z "$YOUR_PHONE_NUMBER" ] || [ -z "$TWILIO_NUMBER_SID" ]
then
  echo 'Missing variable... :/';
  echo 'Please run the setup script as follows:';
  echo '$ YOUR_NAME=Jane YOUR_PHONE_NUMBER=+1234... TWILIO_NUMBER_SID=PN... npm run setup';
  exit 1;
fi

SYNC_SERVICE_NAME="serverless-sms-group-chat";
SYNC_SERVICE_SID=$(twilio api:sync:v1:services:create --friendly-name=$SYNC_SERVICE_NAME -o=json | jq '.[0].sid' -r);
echo "Created new sync service...";
echo $SYNC_SERVICE_SID

SYNC_DOCUMENT_NAME="sms-group-chat-config";
SYNC_DOCUMENT_SID=$(twilio api:sync:v1:services:documents:create --unique-name=sms-group-chat-config --service-sid=$SYNC_SERVICE_SID -o=json | jq '.[0].sid' -r)
echo "Created new sync document...";
echo $SYNC_DOCUMENT_SID

twilio api:sync:v1:services:documents:update --service-sid=$SYNC_SERVICE_SID --sid=$SYNC_DOCUMENT_SID --data="{participants: [{ \"name\": \"$YOUR_NAME\", \"number\": \"$YOUR_PHONE_NUMBER\" }]}"

DEPLOY_OUTPUT=$(npm run deploy)
SMS_ENDPOINT_URL=$(echo $DEPLOY_OUTPUT | grep -o "https://.*/sms/reply")
echo $SMS_ENDPOINT_URL;

twilio phone-numbers:update $TWILIO_NUMBER_SID  --sms-url=$SMS_ENDPOINT_URL -o=json
echo "Number updated..."

echo "Your group SMS chat is ready!!!"
