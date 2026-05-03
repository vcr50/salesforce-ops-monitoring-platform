const getBillingProvider = () => {
  const provider = (process.env.BILLING_PROVIDER || 'stripe').toLowerCase();
  if (!['razorpay', 'stripe'].includes(provider)) {
    throw new Error(`Unsupported billing provider: ${provider}`);
  }
  return provider;
};

module.exports = {
  getBillingProvider
};
