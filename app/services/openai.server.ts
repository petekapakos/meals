import OpenAI from 'openai';

if (!process.env.OPENAI_API_KEY) {
  throw new Error('OPENAI_API_KEY is required');
}

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export interface Meal {
  name: string;
  description: string;
  mainIngredients: string[];
}

export interface GeneratedMealPlan {
  meals: Meal[];
  shoppingList: string[];
}

export const openAiService = {
  async generateMealPlan(): Promise<GeneratedMealPlan> {
    const prompt = `Generate a meal plan for 5 dinners for the week. For each meal, provide:
    1. Name of the dish
    2. Brief description
    3. Main ingredients needed
    
    Then, create a consolidated shopping list for all meals.
    Format the response in JSON with the following structure:
    {
      "meals": [
        {
          "name": "Dish name",
          "description": "Brief description",
          "mainIngredients": ["ingredient1", "ingredient2"]
        }
      ],
      "shoppingList": ["item1", "item2"]
    }`;

    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      temperature: 0.8,
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
      response_format: { type: "json_object" },
    });

    const result = JSON.parse(response.choices[0].message.content || "{}");

    // Ensure the response matches our expected format
    const defaultResponse: GeneratedMealPlan = {
      meals: [],
      shoppingList: []
    };

    return {
      meals: Array.isArray(result.meals) ? result.meals : defaultResponse.meals,
      shoppingList: Array.isArray(result.shoppingList) ? result.shoppingList : defaultResponse.shoppingList
    };
  },
};
