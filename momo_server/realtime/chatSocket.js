/**
 * Socket.IO 실시간 모임 채팅.
 * 명세: docs/실시간서버_기술명세서.md
 */
const { Server } = require("socket.io");

const { verifyAccessToken } = require("../middleware/auth");
const {
  MeetingError,
  createMessage,
  verifyMeetingMember,
  meetingRoom,
  toChatPayload,
} = require("../services/meetingService");

function emitSocketError(socket, code, message) {
  socket.emit("error", { code, message });
}

function mapMeetingError(error) {
  if (error instanceof MeetingError) {
    return { code: error.message, message: error.message };
  }

  return { code: "server", message: "server error" };
}

function extractToken(handshake) {
  const authToken = handshake.auth?.token;
  if (typeof authToken === "string" && authToken.trim()) {
    return authToken.trim();
  }

  const queryToken = handshake.query?.token;
  if (typeof queryToken === "string" && queryToken.trim()) {
    return queryToken.trim();
  }

  return null;
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

/**
 * @param {import("http").Server} httpServer
 * @returns {import("socket.io").Server}
 */
function initChatSocket(httpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"],
    },
  });

  io.use((socket, next) => {
    const user = verifyAccessToken(extractToken(socket.handshake));
    if (!user) {
      return next(new Error("unauthorized"));
    }

    socket.data.user = user;
    return next();
  });

  io.on("connection", (socket) => {
    const userId = socket.data.user.id;

    socket.on("join", async (payload, ack) => {
      try {
        const meetingId = payload?.meetingId;
        if (!isNonEmptyString(meetingId)) {
          const err = { code: "validation", message: "validation" };
          emitSocketError(socket, err.code, err.message);
          if (typeof ack === "function") ack({ success: false, ...err });
          return;
        }

        await verifyMeetingMember(meetingId.trim(), userId);
        await socket.join(meetingRoom(meetingId.trim()));

        if (typeof ack === "function") {
          ack({ success: true, meetingId: meetingId.trim() });
        }
      } catch (error) {
        const mapped = mapMeetingError(error);
        emitSocketError(socket, mapped.code, mapped.message);
        if (typeof ack === "function") {
          ack({ success: false, ...mapped });
        }
      }
    });

    socket.on("leave", (payload) => {
      const meetingId = payload?.meetingId;
      if (!isNonEmptyString(meetingId)) {
        emitSocketError(socket, "validation", "validation");
        return;
      }

      socket.leave(meetingRoom(meetingId.trim()));
    });

    socket.on("chat", async (payload) => {
      try {
        const meetingId = payload?.meetingId;
        const body = payload?.body;

        if (!isNonEmptyString(meetingId)) {
          emitSocketError(socket, "validation", "validation");
          return;
        }

        const room = meetingRoom(meetingId.trim());
        if (!socket.rooms.has(room)) {
          emitSocketError(socket, "not-participant", "not-participant");
          return;
        }

        const result = await createMessage(meetingId.trim(), userId, body);
        io.to(room).emit("chat", toChatPayload(meetingId.trim(), result));
      } catch (error) {
        const mapped = mapMeetingError(error);
        emitSocketError(socket, mapped.code, mapped.message);
      }
    });
  });

  return io;
}

module.exports = { initChatSocket };
