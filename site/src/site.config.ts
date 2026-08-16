export type Chapter = {
  name: string;
  title: string;
  copy: string;
  image: string;
  alt: string;
};

export type Faq = { question: string; answer: string };
export type LegalSection = { title: string; body: string };
export type LegalPage = { title: string; lede: string; sections: LegalSection[] };

export type SiteConfig = {
  name: string;
  url: string;
  tagline: string;
  headline: [string, string];
  lede: string;
  kicker: string;
  summary: string;
  status: string;
  platforms: string[];
  themeColor: string;
  mark: string;
  socialImage: string;
  tokens: {
    paper: string;
    field: string;
    ink: string;
    inkSoft: string;
    inkFaint: string;
    accent: string;
    accentDark: string;
    accentSoft: string;
    lanternA: string;
    lanternB: string;
    lanternC: string;
    blush: string;
    inkOnDark: string;
  };
  hero: { image: string; alt: string; caption: string };
  betaNote: string;
  tension: { statement: string; title: string; copy: string };
  chaptersKicker: string;
  chaptersTitle: string;
  chaptersLede: string;
  chapters: Chapter[];
  fit: { kicker: string; title: string; yes: string; no: string };
  privacy: { kicker: string; title: string; copy: string };
  faqs: Faq[];
  founder: { quote: string; credit: string; note: string };
  closingTitle: [string, string];
  footerFinePrint: string;
  capabilities: string[];
  boundaries: string[];
  lastUpdated: string;
  legal: {
    privacy: LegalPage;
    support: LegalPage;
    terms: LegalPage;
    accessibility: LegalPage;
    testflight: LegalPage & { testing: string; notIncluded: string };
  };
  requiredHomeCopy: string[];
  prohibitedClaims: string[];
};

export const site: SiteConfig = {
  name: "Kith",
  url: "https://kith.significanthobbies.com",
  tagline: "The people you keep close.",
  headline: ["The people", "you keep close."],
  lede: "They float as lanterns. Closer people are larger. Tap someone and write down what just happened.",
  kicker: "Private. On your iPhone.",
  summary: "A private iPhone app for the people you want to stay close to. They float as bubbles sized by closeness, and each person has a dated log of hangouts, calls, gifts, and the small facts that make someone feel known.",
  status: "Invite-only TestFlight beta preparation",
  platforms: ["iPhone"],
  themeColor: "#f4e6d4",
  mark: "/images/brand/mark.png",
  socialImage: "/images/brand/social.png",
  tokens: {
    paper: "#fff6ea",
    field: "#f4e6d4",
    ink: "#3a2418",
    inkSoft: "#6a4a38",
    inkFaint: "rgba(58, 36, 24, 0.15)",
    accent: "#c46a4a",
    accentDark: "#9a3f2a",
    accentSoft: "#e8a06a",
    lanternA: "#c46a4a",
    lanternB: "#e8a06a",
    lanternC: "#e0b04a",
    blush: "#f3ddd0",
    inkOnDark: "#fff6ea"
  },
  hero: {
    image: "/images/screens/constellation.png",
    alt: "Kith’s constellation of people as warm lanterns of different sizes",
    caption: "Closer people take more space. Size is something you set."
  },
  betaNote: "Invite-only iPhone testing. No account. Notes stay on your phone and, if you want, your iCloud.",
  tension: {
    statement: "A contact list is not a relationship.",
    title: "No pipeline. No score.",
    copy: "Kith is for the people you already care about. Closeness is a choice you make, not a number the app infers from how often you text."
  },
  chaptersKicker: "One quiet loop",
  chaptersTitle: "See them. Write it down.",
  chaptersLede: "Open the field, tap someone, leave a few words. That is the whole product.",
  chapters: [
    {
      name: "Field",
      title: "See who is close.",
      copy: "People you add float as lanterns. Family and close friends sit larger than a colleague you barely know.",
      image: "/images/screens/constellation.png",
      alt: "Kith home screen with floating people of different sizes"
    },
    {
      name: "Person",
      title: "Keep the facts that matter.",
      copy: "How you met, a birthday, the thing they always order. A dated log of hangouts, calls, gifts, and notes to remember.",
      image: "/images/screens/person.png",
      alt: "Kith person page for Maya with standing notes and a hangout log"
    }
  ],
  fit: {
    kicker: "An honest fit",
    title: "Made for remembering people. Not managing them.",
    yes: "Kith may fit if you want a warm, private place to remember dinners, calls, and the details that make someone feel known.",
    no: "It is not a CRM, not a contact book, and not a social network. There are no reminders-as-a-product, no imported address book, and no public graph."
  },
  privacy: {
    kicker: "Private by default",
    title: "Your people stay yours.",
    copy: "There is no Kith account and no Kith server. Notes live on the phone. When you are signed into iCloud, they can also sit in your private CloudKit database on your personal Apple team."
  },
  faqs: [
    {
      question: "Do I need an account?",
      answer: "No. Kith does not have accounts. The core app works on the phone. iCloud is optional and uses your Apple ID, not a Kith login."
    },
    {
      question: "Where is my data stored?",
      answer: "In a local JSON document on the iPhone. Signed builds may also mirror that document to your private iCloud database. The developer cannot read it."
    },
    {
      question: "Will it import my contacts?",
      answer: "No. You add people yourself. That is the point."
    },
    {
      question: "Can I join now?",
      answer: "Invite-only TestFlight is being prepared. The verified Apple link will appear on the TestFlight page when it exists. This site will not invent one."
    }
  ],
  founder: {
    quote: "I wanted to remember people without turning them into a spreadsheet.",
    credit: "— Sarthak Agrawal, creator of Kith",
    note: "Kith is an independent app from Significant Hobbies. The word is the old one for the people around you."
  },
  closingTitle: ["Keep them close.", "Write what happened."],
  footerFinePrint: "A private relationship log, not a CRM. © 2026 Sarthak Agrawal.",
  capabilities: [
    "Field: a floating constellation sized by explicit closeness",
    "Person: standing notes, birthday, how you met",
    "Log: hangout, call, message, gift, milestone, remember"
  ],
  boundaries: [
    "No Kith account",
    "No advertising, cross-app tracking, or third-party analytics",
    "No contact-book import",
    "Not a CRM or social network",
    "Core data is local-first; signed builds may use private iCloud storage"
  ],
  lastUpdated: "2026-08-17",
  legal: {
    privacy: {
      title: "Your people stay yours.",
      lede: "Kith is a private, local-first iPhone app. This policy explains the current build in plain language.",
      sections: [
        {
          title: "What the app stores",
          body: "Kith stores the people you add and the notes you write, using Apple’s app storage. Signed builds may synchronize that private document through your iCloud account on the personal Apple team that signs the app."
        },
        {
          title: "What we collect",
          body: "Kith does not operate an account system, advertising SDK, cross-app tracking, or third-party analytics. The developer does not receive your people, notes, or history."
        },
        {
          title: "Apple services and TestFlight",
          body: "When you install a beta through TestFlight, Apple may process beta diagnostics and feedback under Apple’s own terms. Optional iCloud mirroring uses your Apple ID and private CloudKit database."
        },
        {
          title: "Retention and deletion",
          body: "Your data remains until you remove a person or delete the app. There is no Kith account or developer-operated profile server to delete."
        },
        {
          title: "Changes and contact",
          body: "If a future version adds a server or an account, this policy will be updated before that version is distributed. Questions can be sent through the support page."
        },
        { title: "Effective date", body: "Last updated 17 August 2026." }
      ]
    },
    support: {
      title: "Support, without a maze.",
      lede: "Kith is in an early, invite-only TestFlight beta. Here is the fastest way to report a problem.",
      sections: [
        {
          title: "Before reporting a problem",
          body: "Confirm that you are using the newest TestFlight build, then relaunch Kith once. If a visual detail looks wrong, say whether Larger Text, VoiceOver, or Reduce Motion is on."
        },
        {
          title: "What to include",
          body: "Tell us whether you were in the constellation, a person page, or the add-person sheet, what you expected, and what happened instead. Do not include other people’s private notes in screenshots."
        },
        {
          title: "Send feedback",
          body: "Use TestFlight’s Send Beta Feedback action. It keeps feedback tied to the exact beta build."
        }
      ]
    },
    terms: {
      title: "Simple beta terms.",
      lede: "These terms apply to the invite-only Kith TestFlight beta. By installing the beta, you agree to use it as pre-release software.",
      sections: [
        {
          title: "Beta software",
          body: "Kith is under active development. Features may change, data may need to be reset between builds, and the beta may contain defects. Keep anything you cannot afford to lose somewhere else."
        },
        {
          title: "Personal use",
          body: "You may use the beta for personal evaluation through Apple TestFlight. Do not redistribute the app."
        },
        {
          title: "Your content",
          body: "Your notes remain yours. The current app stores them locally and may mirror them to your private iCloud database. The developer does not receive a server-side copy."
        },
        {
          title: "Apple terms",
          body: "Your access to the beta is also governed by the agreements that apply to Apple TestFlight and your Apple account."
        },
        { title: "Changes", body: "Last updated 17 August 2026." }
      ]
    },
    accessibility: {
      title: "Access is part of the experience.",
      lede: "Kith is being built with Apple’s native accessibility tools, not as a separate mode.",
      sections: [
        {
          title: "Current support",
          body: "The constellation lanterns have spoken names, closeness, and circle. Reduce Motion freezes the field. A list with search exists for finding someone quickly and for VoiceOver."
        },
        {
          title: "What we test",
          body: "We test the principal flows in the iOS Simulator, including reduced motion. TestFlight feedback is especially useful for combinations of settings we have not run."
        },
        {
          title: "Report a barrier",
          body: "Use TestFlight’s Send Beta Feedback action and begin the message with Accessibility. Include the screen and intended action. Please omit other people’s notes from screenshots."
        }
      ]
    },
    testflight: {
      title: "The beta is taking shape.",
      lede: "Kith is moving through invite-only TestFlight testing. We will only link to Apple after the enrollment URL is verified.",
      testing: "Add someone, set closeness, open their lantern, and write a short hangout or remember note. Confirm the note is still there after relaunching.",
      notIncluded: "Contact import, photos, and reminder notifications are not in this beta.",
      sections: []
    }
  },
  requiredHomeCopy: ["The people", "lanterns", "private", "TestFlight"],
  prohibitedClaims: ["guaranteed", "import your contacts"]
};

export const links = {
  home: `${site.url}/`,
  privacy: `${site.url}/privacy/`,
  support: `${site.url}/support/`,
  terms: `${site.url}/terms/`,
  accessibility: `${site.url}/accessibility/`,
  testflight: `${site.url}/testflight/`
};
