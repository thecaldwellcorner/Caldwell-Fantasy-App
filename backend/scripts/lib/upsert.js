// Batched upserts + data_sync_runs tracking.

/**
 * Upsert rows in batches. In dry-run mode nothing is written; it just reports
 * what would happen. Returns { upserted, errors }.
 */
export async function batchedUpsert(
  supabase,
  table,
  rows,
  conflict,
  { dryRun = false, batchSize = 500, log = console.log } = {},
) {
  if (rows.length === 0) {
    log(`No rows to upsert into ${table}.`);
    return { upserted: 0, errors: 0 };
  }
  if (dryRun) {
    log(`[dry-run] would upsert ${rows.length} rows into ${table} (onConflict: ${conflict}).`);
    log(`[dry-run] sample row: ${JSON.stringify(rows[0])}`);
    return { upserted: 0, errors: 0 };
  }

  let upserted = 0;
  let errors = 0;
  const batches = Math.ceil(rows.length / batchSize);
  for (let i = 0; i < rows.length; i += batchSize) {
    const batch = rows.slice(i, i + batchSize);
    const n = Math.floor(i / batchSize) + 1;
    const { error } = await supabase.from(table).upsert(batch, { onConflict: conflict });
    if (error) {
      errors += batch.length;
      log(`  batch ${n}/${batches} ERROR: ${error.message}`);
    } else {
      upserted += batch.length;
      log(`  batch ${n}/${batches} ok — ${upserted}/${rows.length} upserted`);
    }
  }
  return { upserted, errors };
}

export async function startSyncRun(supabase, { syncType, source, dryRun = false }) {
  if (dryRun || !supabase) return null;
  const { data, error } = await supabase
    .from("data_sync_runs")
    .insert({ sync_type: syncType, source, started_at: new Date().toISOString(), status: "running" })
    .select("id")
    .single();
  if (error) {
    console.warn(`Could not record data_sync_runs start: ${error.message}`);
    return null;
  }
  return data.id;
}

export async function finishSyncRun(supabase, id, { status, rowsProcessed = 0, errorMessage = null }) {
  if (!id || !supabase) return;
  const { error } = await supabase
    .from("data_sync_runs")
    .update({
      completed_at: new Date().toISOString(),
      status,
      rows_processed: rowsProcessed,
      error_message: errorMessage,
    })
    .eq("id", id);
  if (error) console.warn(`Could not record data_sync_runs finish: ${error.message}`);
}
