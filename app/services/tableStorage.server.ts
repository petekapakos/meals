import { TableClient } from "@azure/data-tables";
import { DefaultAzureCredential } from "@azure/identity";

const tableName = "mealplans";
const accountName = process.env.AZURE_STORAGE_ACCOUNT_NAME;

if (!accountName) {
  throw new Error("Azure Storage Account Name is required");
}

const credential = new DefaultAzureCredential();
const tableClient = new TableClient(
  `https://${accountName}.table.core.windows.net`,
  tableName,
  credential
);

export interface MealPlan {
  partitionKey: string;
  rowKey: string;
  meals: string;
  shoppingList: string;
  createdAt: Date;
}

export const tableStorageService = {
  async initialize() {
    try {
      await tableClient.createTable();
    } catch (error) {
      // Table might already exist
      console.log("Table might already exist:", error);
    }
  },

  async saveMealPlan(meals: string, shoppingList: string): Promise<MealPlan> {
    const timestamp = new Date().toISOString();
    const mealPlan: MealPlan = {
      partitionKey: "mealplans",
      rowKey: timestamp,
      meals,
      shoppingList,
      createdAt: new Date(),
    };

    await tableClient.createEntity(mealPlan);
    return mealPlan;
  },

  async getLatestMealPlan(): Promise<MealPlan | null> {
    const iterator = tableClient.listEntities<MealPlan>({
      queryOptions: {
        filter: "PartitionKey eq 'mealplans'",
      }
    });

    let latestMealPlan: MealPlan | null = null;
    let latestDate = new Date(0);

    for await (const entity of iterator) {
      if (entity.createdAt > latestDate) {
        latestMealPlan = entity;
        latestDate = entity.createdAt;
      }
    }

    return latestMealPlan;
  }
};
