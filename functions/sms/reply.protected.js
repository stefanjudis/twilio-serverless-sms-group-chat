'use strict';

function getGroupedParticipants(participants, participantNumber) {
  return participants.reduce(
    (acc, p) => {
      p.number === participantNumber
        ? (acc.activeParticipant = p)
        : acc.participants.push(p);

      return acc;
    },
    { participants: [], activeParticipant: null }
  );
}

function sendGroupMessage(participants, message) {
  return Promise.all(
    participants.map(({ number: to }) => {
      const from = process.env.GROUP_SMS_NUMBER;
      return client.messages.create({ body: message, from, to });
    })
  );
}

const COMMANDS = {
  /**
   * Show help and available commands
   */
  help: {
    desc: 'Show available commands',
    example: '/help',
    getResponse: async () => {
      return `Available slash-commands:\n\n${Object.keys(COMMANDS)
        .map(
          cmd =>
            `${COMMANDS[cmd].desc} (${cmd})\nUsage: '${COMMANDS[cmd].example}'`
        )
        .join('\n\n')}`;
    }
  },
  /**
   * Add a number to the channel
   */
  add: {
    desc: 'Add person to the group',
    example: '/add +49171234567 Jane',
    getResponse: async (args, { document, senderNumber }) => {
      const [number, name] = args;
      document.data.participants.push({
        name,
        number
      });

      await document.update({ data: document.data });

      return `${name} was added to the group.`;
    }
  },
  /**
   * Leave the channel
   */
  leave: {
    desc: 'Leave the SMS group chat',
    example: '/leave',
    getResponse: async (args, { document, senderNumber, twiml }) => {
      const {
        activeParticipant: removedParticipant,
        participants: updatedParticipants
      } = getGroupedParticipants(document.data.participants, senderNumber);

      document.data.participants = updatedParticipants;
      await document.update({ data: document.data });

      await sendGroupMessage(
        updatedParticipants,
        `${removedParticipant.name} left the group...`
      );

      return "You left the group chat and won't receive more messages...";
    }
  },

  /**
   * List all members in the channel
   */
  list: {
    desc: 'List all participants',
    example: '/list',
    getResponse: async (args, { document }) => {
      const list = document.data.participants
        .map(({ name, number }) => `- ${name} (${number})`)
        .join('\n');

      return `People in this channel:\n\n${list}`;
    }
  }
};

exports.handler = function(context, event, callback) {
  const client = context.getTwilioClient();
  const twiml = new Twilio.twiml.MessagingResponse();

  const senderNumber = event.From;
  const senderMsg = event.Body;

  client.sync
    .services(process.env.SYNC_SERVICE_SID)
    .documents(process.env.SYNC_DOCUMENT_SID)
    .fetch()
    .then(async document => {
      const isCommand = senderMsg.startsWith('/');
      const senderIsInGroup = document.data.participants.some(participant => {
        return participant.number === senderNumber;
      });

      if (!senderIsInGroup) {
        twiml.message(
          "You don't belong to this group. Please ask a member to add you."
        );
        return callback(null, twiml);
      }

      if (isCommand) {
        const [baseCommand, ...args] = senderMsg.slice(1).split(' ');

        try {
          twiml.message(
            await COMMANDS[baseCommand].getResponse(args, {
              document,
              senderNumber
            })
          );

          return callback(null, twiml);
        } catch (e) {
          console.log(e);
          twiml.message(
            `'${baseCommand}' does not exist...\n${COMMANDS.help.getResponse()}`
          );

          return callback(null, twiml);
        }
      } else {
        const { activeParticipant, participants } = getGroupedParticipants(
          document.data.participants,
          senderNumber
        );

        sendGroupMessage(
          participants,
          `${activeParticipant.name}: ${senderMsg}`
        )
          .then(messages => {
            console.log(messages);
            callback(null, '');
          })
          .catch(e => {
            console.log(e);
            callback(null, '');
          });
      }
    })
    .catch(e => console.log(e));
};
