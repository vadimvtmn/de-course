-- Крок 9: gold.fact_pull_request. Специфікація: ../../SPEC.md → «Крок 9».
-- Джерело: {{ ref('pull_requests') }}. Грануляція: PR.
-- pr_id = md5(concat_ws('|', repo_name, cast(pr_number as string)));
-- merged_date_id — NULL, якщо не змерджено; label_count через CASE (size(NULL) = -1).
-- Колонки: pr_id, repo_id, author_id, opened_date_id, merged_date_id, state, is_merged, is_draft,
--          additions, deletions, churn, changed_files, commits_count, comments, review_comments,
--          hours_open, label_count.

-- TODO: замініть заглушку на запит згідно зі SPEC.md
with 
    prep as (
        select 
            md5(concat_ws('|', repo_name, pr_number)) as pr_id,
            md5(repo_name) as repo_id,
            md5(author_login) as author_id,
            date_format(opened_at, 'yyyyMMdd') as opened_date_id,
            date_format(merged_at, 'yyyyMMdd') as merged_date_id,
            state,
            is_merged,
            is_draft,
            additions,
            deletions,
            churn,
            changed_files,
            commits_count,
            comments,
            review_comments,
            hours_open, 
            size(label_names) as label_count
        from {{ ref('pull_requests') }}
    )

    select
        cast(pr_id              as string   ) as pr_id,
        cast(repo_id            as string   ) as repo_id,
        cast(author_id          as string   ) as author_id,
        cast(opened_date_id     as int      ) as opened_date_id,
        cast(merged_date_id     as int      ) as merged_date_id,
        cast(state              as string   ) as state,
        cast(is_merged          as boolean  ) as is_merged,
        cast(is_draft           as boolean  ) as is_draft,
        cast(additions          as int      ) as additions,
        cast(deletions          as int      ) as deletions,
        cast(churn              as int      ) as churn,
        cast(changed_files      as int      ) as changed_files,
        cast(commits_count      as int      ) as commits_count,
        cast(comments           as int      ) as comments,
        cast(review_comments    as int      ) as review_comments,
        cast(hours_open         as double   ) as hours_open,
        cast(label_count        as int      ) as label_count
    from prep
