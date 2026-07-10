// Minimal, dependency-free CSV parser that handles quoted fields, escaped
// quotes ("") and commas/newlines inside quotes. Returns an array of objects
// keyed by the header row.

export function parseCSV(text) {
  const rows = [];
  let field = "";
  let record = [];
  let inQuotes = false;

  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === ",") {
      record.push(field);
      field = "";
    } else if (c === "\n") {
      record.push(field);
      rows.push(record);
      record = [];
      field = "";
    } else if (c !== "\r") {
      field += c;
    }
  }
  if (field.length > 0 || record.length > 0) {
    record.push(field);
    rows.push(record);
  }

  const header = rows.shift();
  if (!header) return [];

  return rows
    .filter((r) => !(r.length === 1 && r[0] === ""))
    .map((r) => {
      const obj = {};
      header.forEach((h, idx) => {
        obj[h] = r[idx] ?? "";
      });
      return obj;
    });
}

/** Parse a CSV cell to a number, treating "", "NA", "NaN" as null (not 0). */
export function num(value) {
  if (value === undefined || value === null) return null;
  const v = String(value).trim();
  if (v === "" || v === "NA" || v === "NaN" || v === "null") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

/** Parse a CSV cell to an integer or null. */
export function int(value) {
  const n = num(value);
  return n === null ? null : Math.trunc(n);
}
