// Convex checks the access tokens Convex Auth signs against this issuer.
export default {
  providers: [
    {
      domain: process.env.CONVEX_SITE_URL,
      applicationID: "convex",
    },
  ],
};
