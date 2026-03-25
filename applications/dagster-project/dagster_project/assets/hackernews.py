"""
HackerNews assets - based on official Dagster tutorial.
Fetches top stories from HackerNews API and analyzes them.

Reference: https://docs.dagster.io/tutorial
"""
import re
from typing import Dict, List
from collections import Counter

import pandas as pd
import requests
from dagster import asset, MetadataValue, AssetExecutionContext


@asset(
    description="Fetch IDs of top 100 HackerNews stories",
    group_name="hackernews",
    compute_kind="api",
)
def hackernews_top_story_ids(context: AssetExecutionContext) -> List[int]:
    """
    Fetch the IDs of the current top stories on HackerNews.

    Returns:
        List of story IDs
    """
    url = "https://hacker-news.firebaseio.com/v0/topstories.json"

    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        story_ids = response.json()[:100]  # Get top 100

        context.log.info(f"Fetched {len(story_ids)} top story IDs")
        context.add_output_metadata({
            "num_stories": len(story_ids),
            "first_id": story_ids[0] if story_ids else None,
            "last_id": story_ids[-1] if story_ids else None,
        })
        return story_ids
    except Exception as e:
        context.log.error(f"Failed to fetch story IDs: {str(e)}")
        raise


@asset(
    description="Fetch full details of top HackerNews stories",
    group_name="hackernews",
    compute_kind="api",
)
def hackernews_top_stories(
    context: AssetExecutionContext,
    hackernews_top_story_ids: List[int],
) -> pd.DataFrame:
    """
    Fetch the full content of top HackerNews stories.

    Args:
        hackernews_top_story_ids: List of story IDs to fetch

    Returns:
        DataFrame with story details
    """
    stories = []

    for story_id in hackernews_top_story_ids[:50]:  # Limit to 50 for demo
        try:
            url = f"https://hacker-news.firebaseio.com/v0/item/{story_id}.json"
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            story = response.json()

            if story and story.get("type") == "story":
                stories.append({
                    "id": story.get("id"),
                    "title": story.get("title", ""),
                    "url": story.get("url", ""),
                    "score": story.get("score", 0),
                    "by": story.get("by", ""),
                    "time": story.get("time", 0),
                    "descendants": story.get("descendants", 0),
                })
        except Exception as e:
            context.log.warning(f"Failed to fetch story {story_id}: {str(e)}")
            continue

    df = pd.DataFrame(stories)

    context.log.info(f"Fetched {len(df)} stories successfully")
    context.add_output_metadata({
        "num_stories": len(df),
        "total_score": int(df["score"].sum()) if len(df) > 0 else 0,
        "avg_score": float(df["score"].mean()) if len(df) > 0 else 0,
        "preview": MetadataValue.md(df.head(10).to_markdown()) if len(df) > 0 else "No data",
    })
    return df


@asset(
    description="Analyze word frequency in HackerNews story titles",
    group_name="hackernews",
    compute_kind="python",
)
def most_frequent_words(
    context: AssetExecutionContext,
    hackernews_top_stories: pd.DataFrame,
) -> Dict[str, int]:
    """
    Find the most frequent words in story titles.

    Args:
        hackernews_top_stories: DataFrame of stories

    Returns:
        Dictionary of word frequencies
    """
    # Combine all titles
    all_titles = " ".join(hackernews_top_stories["title"].astype(str).tolist())

    # Clean and tokenize
    words = re.findall(r"\b[a-z]{4,}\b", all_titles.lower())

    # Remove common stopwords
    stopwords = {"that", "this", "with", "from", "have", "for", "and", "the", "are", "was"}
    words = [word for word in words if word not in stopwords]

    # Count frequencies
    word_counts = Counter(words)
    top_words = dict(word_counts.most_common(20))

    context.log.info(f"Analyzed {len(words)} words, found {len(word_counts)} unique words")
    table_rows = [f"| {word} | {count} |" for word, count in top_words.items()]
    table_md = "| Word | Count |\n|------|-------|\n" + "\n".join(table_rows)
    context.add_output_metadata({
        "num_words_analyzed": len(words),
        "num_unique_words": len(word_counts),
        "top_word": list(top_words.keys())[0] if top_words else None,
        "top_word_count": list(top_words.values())[0] if top_words else 0,
        "word_frequencies": MetadataValue.md(table_md),
    })
    return top_words
