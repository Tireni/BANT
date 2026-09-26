import { User } from "@/types/user";

export const mockUsers: User[] = [
  ["u1", "Alex Johnson", "alexj", "University of Lagos", "#0E96F6", "Computer Science. Afrobeats. Football. Always down for random gist.", true, "r1"],
  ["u2", "Sarah Ade", "sarahade", "University of Lagos", "#43D88B", "Mass Comm. Voice notes and late-night gist.", true, "r1"],
  ["u3", "Tobi Martins", "tobim", "University of Lagos", "#8B5CF6", "Engineering student. Hostel updates plug.", true, "r1"],
  ["u4", "Aisha Bello", "aishab", "Ahmadu Bello University", "#F79009", "Law student. Music, books, and spicy debates.", true, "r1"],
  ["u5", "Daniel Okafor", "danielok", "University of Nigeria, Nsukka", "#22A3FF", "Tech, portfolio building, and campus stories.", true, "r2"],
  ["u6", "Chidi Okafor", "chidix", "University of Lagos", "#F04438", "Final year. Surviving project season.", true, "r1"],
  ["u7", "Amaka Eze", "amakae", "University of Ibadan", "#4CE09A", "Study rooms and calm conversations.", true, "r3"],
  ["u8", "Favour James", "favourj", "Lagos State University", "#A78BFA", "Loves football and random talks.", true, "r4"],
  ["u9", "Samuel Peter", "samp", "Covenant University", "#087BD1", "Frontend, gaming, and anime.", false, undefined],
  ["u10", "Mariam Ibrahim", "mariamib", "Bayero University Kano", "#F79009", "Quiet listener until music comes up.", true, "r5"],
  ["u11", "Grace Udo", "graceu", "University of Uyo", "#43D88B", "Always online during study breaks.", true, "r2"],
  ["u12", "Zainab Musa", "zainabm", "University of Abuja", "#8B5CF6", "Public health. Big on safe spaces.", true, "r6"],
  ["u13", "David Balogun", "davidb", "Obafemi Awolowo University", "#0E96F6", "Football arguments and career talks.", true, "r4"],
  ["u14", "Kemi Lawal", "kemil", "Babcock University", "#43D88B", "Books, faith, and soft life plans.", false, undefined],
  ["u15", "Ifeanyi Nwosu", "ifeanyin", "University of Benin", "#F04438", "Music production and campus events.", true, "r5"],
  ["u16", "Ruth Essien", "ruthe", "University of Calabar", "#22A3FF", "Freshers corner regular.", true, "r7"],
  ["u17", "Emeka Obi", "emekao", "Federal University of Technology Akure", "#8B5CF6", "Code, hardware, and hostel wahala.", true, "r8"],
  ["u18", "Halima Yusuf", "halimay", "University of Ilorin", "#4CE09A", "Study buddy and calm-room host.", false, undefined],
  ["u19", "Bola Sanni", "bolas", "University of Port Harcourt", "#F79009", "Movies, series, and hot takes.", true, "r9"],
  ["u20", "Ese Omoregie", "eseo", "Nnamdi Azikiwe University", "#087BD1", "Random gist, relationships, and music.", true, "r10"]
].map(([id, name, username, university, avatarColor, bio, online, roomId]) => ({
  id: id as string,
  name: name as string,
  username: username as string,
  university: university as string,
  avatarColor: avatarColor as string,
  bio: bio as string,
  online: online as boolean,
  roomId: roomId as string | undefined
}));
