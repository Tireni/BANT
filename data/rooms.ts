import { Room } from "@/types/room";

export const seedRooms: Room[] = [
  ["r1", "Late Night Gist", "No agenda. Just vibes after lectures.", "Gist", "University of Lagos", "public", ["u2", "u3", "u4", "u6"], ["u1", "u7", "u8", "u11"], 18],
  ["r2", "Final Year Wahala", "Project deadlines, supervisors, and survival tips.", "Study", "University of Lagos", "public", ["u5", "u11"], ["u2", "u3", "u14"], 32],
  ["r3", "Tech Bros & Babes", "Portfolio reviews, internships, and tech gist.", "Tech", "University of Ibadan", "public", ["u7", "u9", "u17"], ["u1", "u5", "u13"], 21],
  ["r4", "Football Talk", "Weekend fixtures and campus banter.", "Sports", "Lagos State University", "public", ["u8", "u13"], ["u3", "u6", "u10"], 27],
  ["r5", "Music & Afrobeats", "New drops, playlists, and concert plans.", "Music", "Bayero University Kano", "public", ["u10", "u15"], ["u4", "u19", "u20"], 24],
  ["r6", "Safe Space Check-in", "Talk gently. Listen first.", "Random", "University of Abuja", "public", ["u12"], ["u1", "u14", "u18"], 12],
  ["r7", "Freshers Corner", "Ask anything about campus life.", "Gist", "University of Calabar", "public", ["u16", "u2"], ["u7", "u20"], 19],
  ["r8", "Engineering Students", "Assignments, labs, and hostel light problems.", "Study", "Federal University of Technology Akure", "public", ["u17", "u3"], ["u5", "u9"], 15],
  ["r9", "Movies & Series", "Spoiler-safe recommendations.", "Random", "University of Port Harcourt", "public", ["u19"], ["u8", "u20"], 16],
  ["r10", "Relationship Gist", "Respectful gist only.", "Relationships", "Nnamdi Azikiwe University", "public", ["u20"], ["u2", "u12"], 22],
  ["r11", "Study Break", "Ten minutes away from books.", "Random", "University of Lagos", "public", ["u1", "u7"], ["u4", "u6"], 11],
  ["r12", "Gaming Lobby", "FIFA, CODM, and mobile games.", "Gaming", "Covenant University", "public", ["u9"], ["u13", "u17"], 14],
  ["r13", "Career Talk", "Internships, CVs, LinkedIn, and first jobs.", "Tech", "University of Nigeria, Nsukka", "public", ["u5", "u18"], ["u1", "u12"], 29],
  ["r14", "Hostel Wahala", "Generators, roommates, and survival stories.", "Gist", "University of Lagos", "public", ["u6", "u3"], ["u2", "u8", "u16"], 35],
  ["r15", "Quiet Study Room", "Soft accountability while everyone studies.", "Study", "University of Ilorin", "public", ["u18"], ["u7", "u11"], 9],
  ["r16", "Private Catch-up", "Friends-only conversation.", "Gist", "University of Lagos", "private", ["u1", "u2"], ["u3"], 3],
  ["r17", "Nigerian Students", "Everything campus across Nigeria.", "Random", "University of Abuja", "public", ["u12", "u20"], ["u4", "u10", "u15"], 41],
  ["r18", "Code Portfolio Sprint", "Build, share, improve.", "Tech", "Federal University of Technology Minna", "public", ["u17", "u5"], ["u9", "u11"], 17],
  ["r19", "Afrobeats Debate", "Albums, features, and hot takes.", "Music", "University of Benin", "public", ["u15", "u10"], ["u19", "u20"], 26],
  ["r20", "Random Gist", "Jump in, say hi, stay if it vibes.", "Random", "University of Uyo", "public", ["u11", "u8"], ["u1", "u14", "u16"], 20]
].map(([id, title, description, category, university, privacy, speakerIds, listenerIds, participantCount]) => ({
  id: id as string,
  title: title as string,
  slug: (title as string).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, ""),
  description: description as string,
  category: category as Room["category"],
  university: university as string,
  privacy: privacy as Room["privacy"],
  speakerIds: speakerIds as string[],
  listenerIds: listenerIds as string[],
  participantCount: participantCount as number,
  isLive: true
}));
