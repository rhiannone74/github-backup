defmodule AppWeb.EventController do
  use AppWeb, :controller
  alias AppWeb.EventType
  alias App.{Comment, Issue, Repo}
  alias Ecto.Changeset

  @github_api Application.get_env(:app, :github_api)
  @s3_api Application.get_env(:app, :s3_api)

  def new(conn, payload) do
    headers = Enum.into(conn.req_headers, %{})
    x_github_event = Map.get(headers, "x-github-event")
    github_webhook_action = payload["action"]

    case EventType.get_event_type(x_github_event, github_webhook_action ) do
      :new_installation ->
        token = @github_api.get_installation_token(payload["installation"]["id"])
        issues = @github_api.get_issues(token, payload, 1, [])
        comments = @github_api.get_comments(token, payload)

        conn
        |> put_status(200)
        |> json(%{ok: "new installation"})

      :issue_created ->
        issue_params = %{
          issue_id: payload["issue"]["id"],
          title: payload["issue"]["title"],
          comments: [
            %{
              comment_id: "#{payload["issue"]["id"]}_1",
              versions: [%{author: payload["issue"]["user"]["login"]}]
            }
          ]
        }

        changeset = Issue.changeset(%Issue{}, issue_params)
        issue = Repo.insert!(changeset)

        comment = payload["issue"]["body"]
        version_id = issue.comments
                     |> List.first()
                     |> Map.get(:versions)
                     |> List.first()
                     |> Map.get(:id)
        content = Poison.encode!(%{version_id => comment})
        @s3_api.save_comment(issue.issue_id, content)

        conn
        |> put_status(200)
        |> json(%{ok: "issue created"})

      :issue_edited ->
        issue_id = payload["issue"]["id"]

        if Map.has_key?(payload["changes"], "title") do
          %{"title" => _change} ->
            issue = Repo.get_by!(Issue, issue_id: issue_id)
            issue = Changeset.change issue, title: payload["issue"]["title"]
            Repo.update!(issue)
        end

        if Map.has_key?(payload["changes"], "title") do
          comment = payload["issue"]["body"]
          author = payload["sender"]["login"]
          add_comment_version("#{issue_id}_1", comment, author)
        end

        conn
        |> put_status(200)
        |> json(%{ok: "issue edited"})

      :comment_created ->
        issue_id = payload["issue"]["id"]
        issue = Repo.get_by!(Issue, issue_id: issue_id)
        comment_params = %{
          comment_id: "#{payload["comment"]["id"]}",
          versions: [%{author: payload["comment"]["user"]["login"]}]
        }
        changeset = Ecto.build_assoc(issue, :comments, comment_params)
        comment = Repo.insert!(changeset)

        version = List.first(comment.versions)
        update_s3_file(issue_id, version.id, payload["comment"]["body"])

        conn
        |> put_status(200)
        |> json(%{ok: "comment created"})

      :comment_edited ->
        comment_id = payload["comment"]["id"]
        comment = payload["comment"]["body"]
        author = payload["sender"]["login"]
        add_comment_version(comment_id, comment, author)

        conn
        |> put_status(200)
        |> json(%{ok: "comment edited"})

      _ -> nil
    end
  end

  defp update_s3_file(issue_id, version_id, comment) do
    {:ok, s3_issue} = @s3_api.get_issue(issue_id)
    content = Poison.decode!(s3_issue.body)
    content = Map.put(content, version_id, comment)
    @s3_api.save_comment(issue_id, Poison.encode!(content))
  end

  defp add_comment_version(comment_id, comment, author) do
    comment = Repo.get_by!(Comment, comment_id: "#{comment_id}")
    version_params = %{author: author}
    changeset = Ecto.build_assoc(comment, :versions, version_params)
    version = Repo.insert!(changeset)
    update_s3_file(issue_id, version.id, comment)
  end
end
