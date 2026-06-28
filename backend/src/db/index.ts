import { config } from "../config.js";
import { MemoryRepository } from "./memoryRepository.js";
import { PostgresRepository } from "./postgresRepository.js";
import type { MetricsRepository } from "./repository.js";

let repoSingleton: MetricsRepository | undefined;

/**
 * Returns the process-wide repository. Chooses PostgreSQL when DATA_STORE=postgres,
 * otherwise an in-memory store so the service runs with zero external dependencies.
 */
export function getRepository(): MetricsRepository {
  if (!repoSingleton) {
    repoSingleton =
      config.dataStore === "postgres"
        ? new PostgresRepository(config.databaseUrl)
        : new MemoryRepository();
  }
  return repoSingleton;
}

export type { MetricsRepository } from "./repository.js";
