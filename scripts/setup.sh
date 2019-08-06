#!/bin/bash
set -e

if [ -z "$MY_NAME" ] || [ -z "$MY_PHONE_NUMBER" ]
then
  echo 'Missing variable... :/';
  echo 'Please run the setup script as follows:';
  echo '$ MY_NAME=Jane MY_PHONE_NUMBER=+123... npm run setup';
  exit 1;
fi

TWILIO_NUMBER=$(twilio api:core:available-phone-numbers:mobile:list --country-code DE -o json | jq -r '.[0] | .phoneNumber')
twilio api:core:incoming-phone-numbers:local:create --phone-number="$TWILIO_NUMBER" -o json | jq -r '.[0] | .friendlyName' > /dev/null
echo "Bought number..."
echo $TWILIO_NUMBER

SYNC_SERVICE_NAME="serverless-sms-group-chat";
SYNC_SERVICE_SID=$(twilio api:sync:v1:services:create --friendly-name=$SYNC_SERVICE_NAME -o=json | jq '.[0].sid' -r);
echo "Created new sync service...";
echo $SYNC_SERVICE_SID

SYNC_DOCUMENT_NAME="sms-group-chat-config";
SYNC_DOCUMENT_SID=$(twilio api:sync:v1:services:documents:create --unique-name=sms-group-chat-config --service-sid=$SYNC_SERVICE_SID -o=json | jq '.[0].sid' -r)
echo "Created new sync document...";
echo $SYNC_DOCUMENT_SID

twilio api:sync:v1:services:documents:update --service-sid=$SYNC_SERVICE_SID --sid=$SYNC_DOCUMENT_SID --data="{ \"groupChatNumber\": \"$TWILIO_NUMBER\", participants: [{ \"name\": \"$MY_NAME\", \"number\": \"$MY_PHONE_NUMBER\" }]}" > /dev/null

echo -e "TWILIO_NUMBER=$TWILIO_NUMBER\nSYNC_SERVICE_SID=$SYNC_SERVICE_SID\nSYNC_DOCUMENT_SID=$SYNC_DOCUMENT_SID" > .env
echo "Wrote .env file"

DEPLOY_OUTPUT=$(twilio serverless:deploy --force)
SMS_ENDPOINT_URL=$(echo $DEPLOY_OUTPUT | grep -o "https://.*/sms/reply")
echo "Deployed Twilio Runtime Function"
echo $SMS_ENDPOINT_URL;

twilio phone-numbers:update $TWILIO_NUMBER  --sms-url=$SMS_ENDPOINT_URL -o=json > /dev/null
echo "Updated number with new function URL..."

twilio api:core:messages:create --from=$TWILIO_NUMBER --to=$MY_PHONE_NUMBER --body="Hello $MY_NAME. Happy to have you. Send '/help' to see all commands in your new SMS group chat." -o=json > /dev/null

echo "Your group SMS chat is ready!!!"
