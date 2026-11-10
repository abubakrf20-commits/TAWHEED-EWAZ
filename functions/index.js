/**
 * توحید — توابع سرور
 *
 * `sendBroadcast`: به‌محض نوشته شدن سندی در `admin/outbox/{docId}`
 * (توسط داشبورد وب مدیر یا پنل اپ)، اعلان پوش به موضوع `all`
 * ارسال می‌شود و وضعیت سند به `sent`/`failed` تغییر می‌کند.
 */
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

exports.sendBroadcast = onDocumentCreated(
  { document: 'admin/outbox/{docId}', region: 'us-central1' },
  async (event) => {
    const data = event.data.data();
    if (!data) return;

    const title = (data.title || 'توحید').toString();
    const body = (data.body || '').toString();

    try {
      await getMessaging().send({
        topic: 'all',
        notification: { title, body },
        android: {
          notification: {
            channel_id: 'custom_reminders_v2',
            sound: 'ios17',
            color: '#C48A27',
            icon: 'ic_notification',
          },
        },
      });
      await event.data.ref.update({ status: 'sent', sentAt: new Date() });
    } catch (error) {
      await event.data.ref.update({
        status: 'failed',
        error: String(error),
        sentAt: new Date(),
      });
    }
  },
);