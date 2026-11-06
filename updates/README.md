# Update feed staging
After producing and testing a notarized release, copy its generated appcast.xml
here and run the protected Publish update feed workflow. No placeholder feed is
published: until a real signed archive is available, the workflow fails closed.
Keep prereleases on a separate feed.
