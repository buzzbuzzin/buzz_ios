import Stripe from "https://esm.sh/stripe@14.21.0?target=deno"

async function resolveCustomer(
  stripe: Stripe,
  customerRef: string | Stripe.Customer | Stripe.DeletedCustomer | null,
) {
  if (!customerRef) {
    return null
  }

  if (typeof customerRef !== "string") {
    return customerRef.deleted ? null : customerRef
  }

  const customer = await stripe.customers.retrieve(customerRef)
  if (!customer || customer.deleted) {
    return null
  }

  return customer
}

export async function findOrCreateCustomerForUser(stripe: Stripe, userId: string) {
  const existingCustomerId = await findCustomerForUser(stripe, userId)
  if (existingCustomerId) {
    return existingCustomerId
  }

  const newCustomer = await stripe.customers.create({
    metadata: { user_id: userId },
  })

  return newCustomer.id
}

export async function findCustomerForUser(stripe: Stripe, userId: string) {
  const existingCustomers = await stripe.customers.search({
    query: `metadata['user_id']:'${userId}'`,
  })

  if (existingCustomers.data.length > 0) {
    return existingCustomers.data[0].id
  }

  return null
}

export async function paymentIntentBelongsToUser(
  stripe: Stripe,
  paymentIntent: Stripe.PaymentIntent,
  userId: string,
) {
  if (paymentIntent.metadata?.user_id === userId || paymentIntent.metadata?.buyer_id === userId) {
    return true
  }

  const customer = await resolveCustomer(stripe, paymentIntent.customer)
  return customer?.metadata?.user_id === userId
}

export async function subscriptionBelongsToUser(
  stripe: Stripe,
  subscription: Stripe.Subscription,
  userId: string,
) {
  const customer = await resolveCustomer(stripe, subscription.customer)
  return customer?.metadata?.user_id === userId
}
