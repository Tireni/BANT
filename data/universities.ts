import { University } from "@/types/university";

export const universities: University[] = [
  ["unilag", "University of Lagos", "UNILAG", "Lagos"],
  ["ui", "University of Ibadan", "UI", "Ibadan"],
  ["uniabuja", "University of Abuja", "UNIABUJA", "Abuja"],
  ["baze", "Baze University", "BAZE", "Abuja"],
  ["nile", "Nile University of Nigeria", "NILE", "Abuja"],
  ["unn", "University of Nigeria, Nsukka", "UNN", "Nsukka"],
  ["oau", "Obafemi Awolowo University", "OAU", "Ile-Ife"],
  ["abu", "Ahmadu Bello University", "ABU", "Zaria"],
  ["lasu", "Lagos State University", "LASU", "Lagos"],
  ["cu", "Covenant University", "CU", "Ota"],
  ["babcock", "Babcock University", "BABCOCK", "Ilishan"],
  ["uniben", "University of Benin", "UNIBEN", "Benin City"],
  ["unilorin", "University of Ilorin", "UNILORIN", "Ilorin"],
  ["uniport", "University of Port Harcourt", "UNIPORT", "Port Harcourt"],
  ["unizik", "Nnamdi Azikiwe University", "UNIZIK", "Awka"],
  ["futa", "Federal University of Technology Akure", "FUTA", "Akure"],
  ["futminna", "Federal University of Technology Minna", "FUTMINNA", "Minna"],
  ["buk", "Bayero University Kano", "BUK", "Kano"],
  ["unijos", "University of Jos", "UNIJOS", "Jos"],
  ["unical", "University of Calabar", "UNICAL", "Calabar"],
  ["uniuyo", "University of Uyo", "UNIUYO", "Uyo"],
  ["unimaid", "University of Maiduguri", "UNIMAID", "Maiduguri"]
].map(([id, name, shortName, location]) => ({ id, name, shortName, location }));
