// Kanban model: defaults, parse, validators, panel width (ES5 for QML + Node)
var PALETTE = [
  "#E85D4C", "#E8913A", "#E8C547", "#7BC96F",
  "#3DB89A", "#5B9FD6", "#6B8AFD", "#9B7EDE",
  "#D66BAD", "#A0785A", "#8B95A8", "#5C6673"
];

var FALLBACK_COLOR = "#6B8AFD";
var DEFAULT_BOARD_NAME = "Personal";
var MAX_BOARDS = 50;
var MAX_COLUMNS = 40;
var MAX_TICKETS = 10000;
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function pad2(n) {
  return n < 10 ? "0" + n : String(n);
}

function clip(value, max) {
  var s = typeof value === "string" ? value : "";
  return s.length > max ? s.substring(0, max) : s;
}

function trimStr(value) {
  if (value === null || value === undefined) return null;
  return String(value).replace(/^\s+|\s+$/g, "");
}

function boundedText(value, max) {
  var s = trimStr(value);
  if (s === null || s.length < 1 || s.length > max) return null;
  return s;
}

function safeId(raw, prefix) {
  if (typeof raw === "string" && /^[a-z]{1,8}-[0-9a-f]{8}$/.test(raw)) return raw;
  return newId(prefix);
}

function sanitizeNotify(value) {
  var s = String(value || "").replace(/[\x00-\x1f\x7f]/g, " ").replace(/\s+/g, " ");
  s = s.replace(/^\s+|\s+$/g, "");
  return s.length > 160 ? s.substring(0, 157) + "..." : s;
}

function formatDay(value) {
  var day = String(value || "").substring(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return "";
  var p = day.split("-");
  return Number(p[2]) + " " + MONTHS[Number(p[1]) - 1] + " " + p[0];
}

function newId(prefix) {
  var n = Math.floor(Math.random() * 0x100000000);
  return prefix + "-" + ("00000000" + n.toString(16)).slice(-8);
}

function isoNow(date) {
  return date.toISOString();
}

function todayKey(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate());
}

function normalizeHex(value) {
  if (value === null || value === undefined) return null;
  var s = String(value).replace(/^\s+|\s+$/g, "");
  if (s.charAt(0) === "#") s = s.substring(1);
  if (!/^[0-9a-fA-F]{3}$/.test(s) && !/^[0-9a-fA-F]{6}$/.test(s)) return null;
  if (s.length === 3)
    s = s.charAt(0) + s.charAt(0) + s.charAt(1) + s.charAt(1) + s.charAt(2) + s.charAt(2);
  return "#" + s.toUpperCase();
}

function validName(value) {
  return boundedText(value, 40);
}

function validTitle(value) {
  return boundedText(value, 120);
}

function validDescription(value) {
  if (value === null || value === undefined) return "";
  var s = String(value);
  return s.length > 4000 ? null : s;
}

function validDeadline(value) {
  if (value === null || value === undefined || value === "") return { ok: true, value: null };
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return { ok: false };
  var parts = value.split("-");
  var y = parseInt(parts[0], 10);
  var m = parseInt(parts[1], 10);
  var d = parseInt(parts[2], 10);
  var dt = new Date(y, m - 1, d);
  if (dt.getFullYear() !== y || dt.getMonth() !== m - 1 || dt.getDate() !== d) return { ok: false };
  return { ok: true, value: value };
}

function panelWidth(columnCount, columnWidth, columnGap, padding, maxWidth) {
  var w = padding + columnCount * columnWidth + Math.max(0, columnCount - 1) * columnGap;
  return maxWidth > 0 ? Math.min(w, maxWidth) : w;
}

function columnOffset(index, columnWidth, gap, padding) {
  var i = typeof index === "number" && index > 0 ? index : 0;
  return padding + i * (columnWidth + gap);
}

function scrollToReveal(contentX, viewWidth, itemX, itemWidth, maxContentX) {
  var next = contentX;
  if (itemX < contentX) next = itemX;
  else if (itemX + itemWidth > contentX + viewWidth) next = itemX + itemWidth - viewWidth;
  if (next < 0) next = 0;
  if (typeof maxContentX === "number" && next > maxContentX) next = maxContentX;
  return next;
}

function focusInColumn(column, preferredIndex) {
  if (!column) return { columnId: "", ticketId: "" };
  var tickets = column.tickets || [];
  var ticketId = "";
  if (tickets.length > 0) {
    var i = typeof preferredIndex === "number" ? preferredIndex : 0;
    if (i < 0) i = 0;
    if (i >= tickets.length) i = tickets.length - 1;
    ticketId = tickets[i] && tickets[i].id ? tickets[i].id : "";
  }
  return { columnId: column.id || "", ticketId: ticketId };
}

function defaultColumns() {
  return [
    { id: newId("col"), name: "Todo", color: FALLBACK_COLOR, tickets: [] },
    { id: newId("col"), name: "In Progress", color: "#E8913A", tickets: [] },
    { id: newId("col"), name: "Done", color: "#7BC96F", tickets: [] }
  ];
}

function defaultState(now) {
  var boardId = newId("board");
  return {
    version: 1,
    activeBoardId: boardId,
    boards: [{
      id: boardId,
      name: DEFAULT_BOARD_NAME,
      createdAt: isoNow(now),
      columns: defaultColumns()
    }]
  };
}

function normalizeTicket(raw) {
  if (!raw || typeof raw !== "object") return null;
  var deadline = validDeadline(raw.deadline);
  var reminder = validDeadline(raw.lastReminderDate);
  return {
    id: safeId(raw.id, "tkt"),
    title: clip(raw.title, 120),
    description: clip(raw.description, 4000),
    createdAt: typeof raw.createdAt === "string" ? clip(raw.createdAt, 40) : null,
    deadline: deadline.ok ? deadline.value : null,
    lastReminderDate: reminder.ok ? reminder.value : null
  };
}

function takeList(raw, limit, normalize) {
  var out = [];
  if (!Array.isArray(raw)) return out;
  var i;
  var n = Math.min(raw.length, limit);
  for (i = 0; i < n; i++) {
    var item = normalize(raw[i]);
    if (item) out.push(item);
  }
  return out;
}

function normalizeColumn(raw) {
  if (!raw || typeof raw !== "object") return null;
  return {
    id: safeId(raw.id, "col"),
    name: clip(raw.name, 40),
    color: normalizeHex(raw.color) || FALLBACK_COLOR,
    tickets: takeList(raw.tickets, MAX_TICKETS, normalizeTicket)
  };
}

function normalizeBoard(raw) {
  if (!raw || typeof raw !== "object") return null;
  return {
    id: safeId(raw.id, "board"),
    name: clip(raw.name, 40),
    createdAt: typeof raw.createdAt === "string" ? clip(raw.createdAt, 40) : null,
    columns: takeList(raw.columns, MAX_COLUMNS, normalizeColumn)
  };
}

function recoveredResult(now, error) {
  return { ok: true, recovered: true, state: defaultState(now), error: error || null };
}

function parseState(raw, now) {
  if (raw === null || raw === undefined || raw === "") return recoveredResult(now, "missing");
  var parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    return recoveredResult(now, String(err.message || err));
  }
  if (!parsed || typeof parsed !== "object" || parsed.version !== 1 || !Array.isArray(parsed.boards))
    return recoveredResult(now, "invalid schema");
  if (parsed.boards.length === 0) return recoveredResult(now, "no boards");

  var boards = takeList(parsed.boards, MAX_BOARDS, normalizeBoard);
  if (boards.length === 0) return recoveredResult(now, "no boards");

  var activeBoardId = typeof parsed.activeBoardId === "string" ? parsed.activeBoardId : null;
  if (findIndexById(boards, activeBoardId) < 0) activeBoardId = boards[0].id;

  return {
    ok: true,
    recovered: false,
    state: { version: 1, activeBoardId: activeBoardId, boards: boards },
    error: null
  };
}

function cloneState(state) {
  return JSON.parse(JSON.stringify(state));
}

function findIndexById(list, id) {
  if (!list) return -1;
  var i;
  for (i = 0; i < list.length; i++) {
    if (list[i].id === id) return i;
  }
  return -1;
}

function options(items) {
  var out = [];
  if (!items) return out;
  var i;
  for (i = 0; i < items.length; i++)
    out.push({ value: items[i].id, label: items[i].name });
  return out;
}

function labelOf(items, id) {
  if (!items) return id || "";
  var i;
  for (i = 0; i < items.length; i++) {
    var it = items[i];
    if (it.id === id || it.value === id) return it.name || it.label || (id || "");
  }
  return id || "";
}

function findBoardIndex(state, boardId) {
  return findIndexById(state.boards, boardId);
}

function findColumnIndex(board, columnId) {
  return findIndexById(board.columns, columnId);
}

function eachTicket(state, fn) {
  if (!state || !Array.isArray(state.boards)) return;
  var bi, ci, ti;
  for (bi = 0; bi < state.boards.length; bi++) {
    var board = state.boards[bi];
    if (!board || !Array.isArray(board.columns)) continue;
    for (ci = 0; ci < board.columns.length; ci++) {
      var column = board.columns[ci];
      if (!column || !Array.isArray(column.tickets)) continue;
      for (ti = 0; ti < column.tickets.length; ti++) {
        if (fn(board, column, column.tickets[ti], ci, ti) === false) return;
      }
    }
  }
}

function fail(state, error, extra) {
  var out = extra || {};
  out.ok = false;
  out.state = state;
  out.error = error;
  return out;
}

function ok(state, extra) {
  var out = extra || {};
  out.ok = true;
  out.state = state;
  out.error = null;
  return out;
}

function activeBoard(state) {
  if (!state || !Array.isArray(state.boards)) return null;
  var idx = findBoardIndex(state, state.activeBoardId);
  return idx < 0 ? null : state.boards[idx];
}

function findTicket(state, ticketId) {
  var found = null;
  eachTicket(state, function(board, column, ticket, ci, ti) {
    if (ticket.id !== ticketId) return;
    found = { board: board, column: column, ticket: ticket, columnIndex: ci, ticketIndex: ti };
    return false;
  });
  return found;
}

function createBoard(state, name, now) {
  var next = cloneState(state);
  var n = validName(name);
  if (!n) return fail(next, "Invalid board name");
  var boardId = newId("board");
  next.boards.push({
    id: boardId,
    name: n,
    createdAt: isoNow(now),
    columns: defaultColumns()
  });
  next.activeBoardId = boardId;
  return ok(next, { boardId: boardId });
}

function renameBoard(state, boardId, name) {
  var next = cloneState(state);
  var n = validName(name);
  if (!n) return fail(next, "Invalid board name");
  var idx = findBoardIndex(next, boardId);
  if (idx < 0) return fail(next, "Board not found");
  next.boards[idx].name = n;
  return ok(next, { boardId: boardId });
}

function deleteBoard(state, boardId) {
  var next = cloneState(state);
  if (next.boards.length === 1) return fail(next, "Cannot delete the last board");
  var idx = findBoardIndex(next, boardId);
  if (idx < 0) return fail(next, "Board not found");
  var wasActive = next.activeBoardId === boardId;
  next.boards.splice(idx, 1);
  if (wasActive)
    next.activeBoardId = next.boards[idx > 0 ? idx - 1 : 0].id;
  return ok(next, { boardId: boardId });
}

function setActiveBoard(state, boardId) {
  var next = cloneState(state);
  if (findBoardIndex(next, boardId) < 0) return fail(next, "Board not found");
  next.activeBoardId = boardId;
  return ok(next, { boardId: boardId });
}

function withColumn(state, boardId, columnId) {
  var next = cloneState(state);
  var bIdx = findBoardIndex(next, boardId);
  if (bIdx < 0) return { next: next, error: "Board not found" };
  var board = next.boards[bIdx];
  var cIdx = columnId === undefined ? -1 : findColumnIndex(board, columnId);
  if (columnId !== undefined && cIdx < 0)
    return { next: next, error: "Column not found" };
  return { next: next, board: board, bIdx: bIdx, cIdx: cIdx };
}

function createColumn(state, boardId, name, color) {
  var n = validName(name);
  if (!n) return fail(cloneState(state), "Invalid column name");
  var hex = normalizeHex(color);
  if (!hex) return fail(cloneState(state), "Invalid color");
  var ctx = withColumn(state, boardId);
  if (ctx.error) return fail(ctx.next, ctx.error);
  var columnId = newId("col");
  ctx.board.columns.push({ id: columnId, name: n, color: hex, tickets: [] });
  return ok(ctx.next, { boardId: boardId, columnId: columnId });
}

function renameColumn(state, boardId, columnId, name) {
  var n = validName(name);
  if (!n) return fail(cloneState(state), "Invalid column name");
  var ctx = withColumn(state, boardId, columnId);
  if (ctx.error) return fail(ctx.next, ctx.error);
  ctx.board.columns[ctx.cIdx].name = n;
  return ok(ctx.next, { boardId: boardId, columnId: columnId });
}

function recolorColumn(state, boardId, columnId, color) {
  var hex = normalizeHex(color);
  if (!hex) return fail(cloneState(state), "Invalid color");
  var ctx = withColumn(state, boardId, columnId);
  if (ctx.error) return fail(ctx.next, ctx.error);
  ctx.board.columns[ctx.cIdx].color = hex;
  return ok(ctx.next, { boardId: boardId, columnId: columnId });
}

function deleteColumn(state, boardId, columnId) {
  var ctx = withColumn(state, boardId, columnId);
  if (ctx.error) return fail(ctx.next, ctx.error);
  if (ctx.board.columns.length === 1) return fail(ctx.next, "Cannot delete the last column");
  ctx.board.columns.splice(ctx.cIdx, 1);
  return ok(ctx.next, { boardId: boardId, columnId: columnId });
}

function createTicket(state, boardId, columnId, fields, now) {
  fields = fields || {};
  var title = validTitle(fields.title);
  if (!title) return fail(cloneState(state), "Invalid title");
  var description = validDescription(fields.description);
  if (description === null) return fail(cloneState(state), "Invalid description");
  var deadline = validDeadline(fields.deadline);
  if (!deadline.ok) return fail(cloneState(state), "Invalid deadline");
  var ctx = withColumn(state, boardId, columnId);
  if (ctx.error) return fail(ctx.next, ctx.error);
  var ticketId = newId("tkt");
  ctx.board.columns[ctx.cIdx].tickets.push({
    id: ticketId,
    title: title,
    description: description,
    createdAt: isoNow(now),
    deadline: deadline.value,
    lastReminderDate: null
  });
  return ok(ctx.next, { boardId: boardId, columnId: columnId, ticketId: ticketId });
}

function updateTicket(state, boardId, ticketId, fields) {
  var next = cloneState(state);
  fields = fields || {};
  var found = findTicket(next, ticketId);
  if (!found || found.board.id !== boardId)
    return fail(next, found ? "Board not found" : "Ticket not found");
  var title = Object.prototype.hasOwnProperty.call(fields, "title") ? validTitle(fields.title) : undefined;
  var description = Object.prototype.hasOwnProperty.call(fields, "description") ? validDescription(fields.description) : undefined;
  var deadline = Object.prototype.hasOwnProperty.call(fields, "deadline") ? validDeadline(fields.deadline) : undefined;
  if (title === null) return fail(next, "Invalid title");
  if (description === null) return fail(next, "Invalid description");
  if (deadline && !deadline.ok) return fail(next, "Invalid deadline");
  if (title !== undefined) found.ticket.title = title;
  if (description !== undefined) found.ticket.description = description;
  if (deadline !== undefined) found.ticket.deadline = deadline.value;
  return ok(next, { boardId: boardId, ticketId: ticketId });
}

function deleteTicket(state, boardId, ticketId) {
  var next = cloneState(state);
  var found = findTicket(next, ticketId);
  if (!found || found.board.id !== boardId)
    return fail(next, found ? "Board not found" : "Ticket not found");
  found.column.tickets.splice(found.ticketIndex, 1);
  return ok(next, { boardId: boardId, ticketId: ticketId });
}

function clampIndex(index, length) {
  if (typeof index !== "number" || isNaN(index) || index < 0) return 0;
  return index > length ? length : index;
}

function moveTicket(state, boardId, ticketId, toColumnId, toIndex) {
  var next = cloneState(state);
  var found = findTicket(next, ticketId);
  if (!found) return fail(next, "Ticket not found", { moved: false });
  if (found.board.id !== boardId) return fail(next, "Board not found", { moved: false });
  var destColIdx = findColumnIndex(found.board, toColumnId);
  if (destColIdx < 0) return fail(next, "Column not found", { moved: false });

  var srcColIdx = found.columnIndex;
  var srcTktIdx = found.ticketIndex;
  if (srcColIdx === destColIdx && srcTktIdx === toIndex)
    return ok(next, { moved: false });

  var ticket = found.column.tickets.splice(srcTktIdx, 1)[0];
  var destTickets = found.board.columns[destColIdx].tickets;
  var destIndex = (srcColIdx === destColIdx && toIndex > srcTktIdx) ? toIndex - 1 : toIndex;
  var insertAt = clampIndex(destIndex, destTickets.length);
  if (srcColIdx === destColIdx && insertAt === srcTktIdx) {
    destTickets.splice(srcTktIdx, 0, ticket);
    return ok(next, { moved: false });
  }
  destTickets.splice(insertAt, 0, ticket);
  return ok(next, { moved: true, boardId: boardId, ticketId: ticketId });
}

function reorderColumn(state, boardId, columnId, toIndex) {
  var ctx = withColumn(state, boardId, columnId);
  if (ctx.error) return fail(ctx.next, ctx.error);
  if (ctx.cIdx === toIndex) return ok(ctx.next, { boardId: boardId, columnId: columnId });
  var col = ctx.board.columns.splice(ctx.cIdx, 1)[0];
  ctx.board.columns.splice(clampIndex(toIndex, ctx.board.columns.length), 0, col);
  return ok(ctx.next, { boardId: boardId, columnId: columnId });
}

function isDoneColumnName(name) {
  return typeof name === "string" && /^done$/i.test(name);
}

function dueToday(deadline, today) {
  return deadline === today;
}

function overdue(deadline, today) {
  return typeof deadline === "string" && typeof today === "string" && deadline < today;
}

function reminderCandidates(state, today) {
  var out = [];
  eachTicket(state, function(board, column, t) {
    if (!t || !t.deadline || t.lastReminderDate === today || isDoneColumnName(column.name)) return;
    var kind = dueToday(t.deadline, today) ? "due-today" : (overdue(t.deadline, today) ? "overdue" : null);
    if (!kind) return;
    out.push({
      boardId: board.id,
      boardName: board.name,
      ticketId: t.id,
      title: t.title,
      kind: kind
    });
  });
  return out;
}

function markTicketReminded(state, ticketId, today) {
  var next = cloneState(state);
  var found = findTicket(next, ticketId);
  if (!found) return fail(next, "Ticket not found");
  found.ticket.lastReminderDate = today;
  return ok(next, { ticketId: ticketId });
}

function hoverRecap(state, today) {
  var board = activeBoard(state);
  if (!board) return { boardName: "", columns: [], overdueCount: 0 };
  if (today === undefined || today === null) today = todayKey(new Date());
  var columns = [];
  var overdueCount = 0;
  var ci, ti;
  for (ci = 0; ci < board.columns.length; ci++) {
    var column = board.columns[ci];
    var tickets = column.tickets || [];
    columns.push({ name: column.name, count: tickets.length });
    if (isDoneColumnName(column.name)) continue;
    for (ti = 0; ti < tickets.length; ti++) {
      if (overdue(tickets[ti].deadline, today)) overdueCount++;
    }
  }
  return { boardName: board.name, columns: columns, overdueCount: overdueCount };
}

function recapLine(state, today) {
  var recap = hoverRecap(state, today);
  if (!recap || !recap.boardName) return "Easy Kanban";
  var parts = [recap.boardName];
  var i;
  for (i = 0; i < recap.columns.length; i++)
    parts.push(recap.columns[i].name + " " + recap.columns[i].count);
  if (recap.overdueCount > 0) parts.push("Overdue " + recap.overdueCount);
  return parts.join(" · ");
}

function pickTicket(t) {
  return {
    id: t.id,
    title: t.title,
    description: t.description,
    createdAt: t.createdAt,
    deadline: t.deadline,
    lastReminderDate: t.lastReminderDate
  };
}

function savePayload(state) {
  var boards = [];
  var bi, ci, ti;
  if (state && Array.isArray(state.boards)) {
    for (bi = 0; bi < state.boards.length; bi++) {
      var board = state.boards[bi];
      var columns = [];
      if (board && Array.isArray(board.columns)) {
        for (ci = 0; ci < board.columns.length; ci++) {
          var column = board.columns[ci];
          var tickets = [];
          if (column && Array.isArray(column.tickets)) {
            for (ti = 0; ti < column.tickets.length; ti++)
              tickets.push(pickTicket(column.tickets[ti]));
          }
          columns.push({ id: column.id, name: column.name, color: column.color, tickets: tickets });
        }
      }
      boards.push({ id: board.id, name: board.name, createdAt: board.createdAt, columns: columns });
    }
  }
  return { version: 1, activeBoardId: state ? state.activeBoardId : null, boards: boards };
}

function notificationTitle(boardName) {
  return sanitizeNotify("Easy Kanban · " + (boardName || ""));
}

function notificationBody(item) {
  var title = sanitizeNotify(item && item.title);
  return title + (item && item.kind === "due-today" ? " is due today" : " is overdue");
}

if (typeof module !== "undefined") {
  module.exports = {
    PALETTE: PALETTE,
    FALLBACK_COLOR: FALLBACK_COLOR,
    DEFAULT_BOARD_NAME: DEFAULT_BOARD_NAME,
    newId: newId,
    isoNow: isoNow,
    todayKey: todayKey,
    formatDay: formatDay,
    sanitizeNotify: sanitizeNotify,
    normalizeHex: normalizeHex,
    validName: validName,
    validTitle: validTitle,
    validDescription: validDescription,
    validDeadline: validDeadline,
    panelWidth: panelWidth,
    columnOffset: columnOffset,
    scrollToReveal: scrollToReveal,
    focusInColumn: focusInColumn,
    defaultState: defaultState,
    parseState: parseState,
    cloneState: cloneState,
    activeBoard: activeBoard,
    findTicket: findTicket,
    createBoard: createBoard,
    renameBoard: renameBoard,
    deleteBoard: deleteBoard,
    setActiveBoard: setActiveBoard,
    createColumn: createColumn,
    renameColumn: renameColumn,
    recolorColumn: recolorColumn,
    deleteColumn: deleteColumn,
    createTicket: createTicket,
    updateTicket: updateTicket,
    deleteTicket: deleteTicket,
    moveTicket: moveTicket,
    reorderColumn: reorderColumn,
    isDoneColumnName: isDoneColumnName,
    dueToday: dueToday,
    overdue: overdue,
    reminderCandidates: reminderCandidates,
    markTicketReminded: markTicketReminded,
    options: options,
    labelOf: labelOf,
    hoverRecap: hoverRecap,
    recapLine: recapLine,
    savePayload: savePayload,
    notificationTitle: notificationTitle,
    notificationBody: notificationBody
  };
}
