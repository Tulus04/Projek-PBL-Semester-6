import { sendPushToMany } from './app/lib/fcm-admin'

async function run() {
  try {
    const res = await sendPushToMany(
      ['9719313b-9f4d-498a-a53f-dbfaa8baf202'],
      { title: 'Test', body: 'Test', route: '/scan', type: 'session_start' }
    )
    console.log('Result:', res)
  } catch (err) {
    console.error('Crash:', err.message)
  }
}
run()
