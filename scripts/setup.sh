#!/bin/bash
set -e

# load environment vars defined .env file
set -o allexport
source .env
set +o allexport

if [ -z "$YOUR_NAME" ] || [ -z "$YOUR_PHONE_NUMBER" ]
then
  echo 'Missing variable... :/';
  echo 'Please run the setup script as follows:';
  echo '$ YOUR_NAME=Jane YOUR_PHONE_NUMBER=+123... npm run setup';
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

twilio api:sync:v1:services:documents:update --service-sid=$SYNC_SERVICE_SID --sid=$SYNC_DOCUMENT_SID --data="{ \"groupChatNumber\": \"$GROUP_SMS_NUMBER\", participants: [{ \"name\": \"$YOUR_NAME\", \"number\": \"$YOUR_PHONE_NUMBER\" }]}"

echo "Writing .env file"
echo -e "ACCOUNT_SID=$ACCOUNT_SID\nAUTH_TOKEN=$AUTH_TOKEN\nGROUP_SMS_NUMBER=$GROUP_SMS_NUMBER\nSYNC_SERVICE_SID=$SYNC_SERVICE_SID\nSYNC_DOCUMENT_SID=$SYNC_DOCUMENT_SID" > .env

DEPLOY_OUTPUT=$(npm run deploy)
SMS_ENDPOINT_URL=$(echo $DEPLOY_OUTPUT | grep -o "https://.*/sms/reply")
echo $SMS_ENDPOINT_URL;

twilio phone-numbers:update $GROUP_SMS_NUMBER  --sms-url=$SMS_ENDPOINT_URL -o=json
echo "Number updated with new function URL..."

twilio api:core:messages:create --from=$GROUP_SMS_NUMBER --to=$YOUR_PHONE_NUMBER --body="Hello $YOUR_NAME. Happy to have you. Send '/help' to see all commands in your new SMS group chat."

echo "Your group SMS chat is ready!!!"
