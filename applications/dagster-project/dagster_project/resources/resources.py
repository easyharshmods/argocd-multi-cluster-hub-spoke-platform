"""
Dagster resources - reusable components for assets.
"""
import requests
from dagster import ConfigurableResource


class HackerNewsAPIResource(ConfigurableResource):
    """
    Resource for interacting with HackerNews API.
    """

    base_url: str = "https://hacker-news.firebaseio.com/v0"
    timeout: int = 30

    def get_top_story_ids(self) -> list:
        """Fetch IDs of top stories."""
        url = f"{self.base_url}/topstories.json"
        response = requests.get(url, timeout=self.timeout)
        response.raise_for_status()
        return response.json()

    def get_item(self, item_id: int) -> dict:
        """Fetch a specific item by ID."""
        url = f"{self.base_url}/item/{item_id}.json"
        response = requests.get(url, timeout=self.timeout)
        response.raise_for_status()
        return response.json()


# Instantiate the resource
hackernews_api_resource = HackerNewsAPIResource()
