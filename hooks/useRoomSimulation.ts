import { useEffect, useState } from "react";
import { Room } from "@/types/room";

export function useRoomSimulation(room: Room | undefined) {
  const [participantCount, setParticipantCount] = useState(room?.participantCount ?? 0);
  const [activity, setActivity] = useState<string | null>(null);

  useEffect(() => {
    if (!room) return;
    setParticipantCount(room.participantCount);
  }, [room]);

  useEffect(() => {
    setActivity(null);
  }, [room?.participantCount]);

  return { activeSpeakerId: null as string | null, participantCount, activity };
}
