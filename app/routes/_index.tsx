import type { ActionFunctionArgs, LoaderFunctionArgs, MetaFunction } from "@remix-run/node";
import { json } from "@remix-run/node";
import { useLoaderData, useNavigation, Form } from "@remix-run/react";
import { tableStorageService } from "~/services/tableStorage.server";
import { openAiService, type Meal } from "~/services/openai.server";

export const meta: MetaFunction = () => {
  return [
    { title: "Weekly Meal Planner" },
    { name: "description", content: "Generate your weekly meal plan with AI" },
  ];
};

export async function loader({ request }: LoaderFunctionArgs) {
  const mealPlan = await tableStorageService.getLatestMealPlan();
  return json({ mealPlan });
}

export async function action({ request }: ActionFunctionArgs) {
  const generatedPlan = await openAiService.generateMealPlan();

  await tableStorageService.saveMealPlan(
    JSON.stringify(generatedPlan.meals),
    JSON.stringify(generatedPlan.shoppingList)
  );

  return json({ success: true });
}

export default function Index() {
  const { mealPlan } = useLoaderData<typeof loader>();
  const navigation = useNavigation();
  const isGenerating = navigation.state === "submitting";

  const meals: Meal[] = mealPlan ? JSON.parse(mealPlan.meals) : [];
  const shoppingList: string[] = mealPlan ? JSON.parse(mealPlan.shoppingList) : [];

  return (
    <div className="min-h-screen bg-gray-50 py-8 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto">
        <div className="text-center">
          <h1 className="text-3xl font-bold text-gray-900 mb-8">Weekly Meal Planner</h1>
          <Form method="post" className="mb-8">
            <button
              type="submit"
              disabled={isGenerating}
              className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:bg-blue-300"
            >
              {isGenerating ? "Generating..." : "Generate New Meal Plan"}
            </button>
          </Form>
        </div>

        {mealPlan && (
          <div className="space-y-8">
            <div className="bg-white shadow rounded-lg p-6">
              <h2 className="text-xl font-semibold mb-4">This Week's Dinners</h2>
              <div className="space-y-6">
                {meals.map((meal, index) => (
                  <div key={index} className="border-b pb-4 last:border-b-0">
                    <h3 className="text-lg font-medium text-gray-900">{meal.name}</h3>
                    <p className="text-gray-600 mt-1">{meal.description}</p>
                    <div className="mt-2">
                      <h4 className="text-sm font-medium text-gray-700">Main Ingredients:</h4>
                      <ul className="list-disc pl-5 mt-1 text-gray-600">
                        {meal.mainIngredients.map((ingredient, idx) => (
                          <li key={idx}>{ingredient}</li>
                        ))}
                      </ul>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="bg-white shadow rounded-lg p-6">
              <h2 className="text-xl font-semibold mb-4">Shopping List</h2>
              <ul className="list-disc pl-5 space-y-2">
                {shoppingList.map((item, index) => (
                  <li key={index} className="text-gray-800">{item}</li>
                ))}
              </ul>
            </div>
          </div>
        )}

        {!mealPlan && !isGenerating && (
          <div className="text-center text-gray-600">
            No meal plan generated yet. Click the button above to create your first meal plan!
          </div>
        )}
      </div>
    </div>
  );
}
