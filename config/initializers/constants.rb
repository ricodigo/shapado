REPUTATION_CONSTRAINS = {"vote_up" => 15, "flag" => 15, "post_images" => 15,
"comment" => 50, "delete_own_comments" => 50, "vote_down" => 100,
"create_new_tags" => 100, "post_whithout_limits" => 100, "edit_wiki_post" => 100,
"remove_advertising" => 200, "vote_to_open_own_question" => 250, "vote_to_close_own_question" => 250,
"retag_others_questions" => 500, "delete_comments_on_own_questions" => 750,
"edit_others_posts" => 2000, "view_offensive_counts" => 2000, "vote_to_close_any_question" => 3000,
"vote_to_open_any_question" => 3000, "delete_closed_questions" => 10000, "moderate" => 10000}

REPUTATION_REWARDS = YAML.load_file(Rails.root + "config/default_reputation.yml")


REST_AUTH_SITE_KEY         = AppConfig.rest_auth_key
REST_AUTH_DIGEST_STRETCHES = AppConfig.rest_auth_digest_stretches

SANITIZE_CONFIG = {
  :protocols =>  {
                  "a"=>{"href"=>["ftp", "http", "https", "mailto", :relative]},
                  "img"=>{"src"=>["http", "https", :relative]},
                  "blockquote"=>{"cite"=>["http", "https", :relative]},
                  "q"=>{"cite"=>["http", "https", :relative]}
                 },
  :elements  =>  ["a", "b", "blockquote", "br", "caption", "cite", "code", "col",
                  "colgroup", "dd", "dl", "dt", "em", "h1", "h2", "h3", "h4", "h5",
                  "h6", "i", "img", "li", "ol", "p", "pre", "q", "small", "strike",
                  "strong", "sub", "sup", "table", "tbody", "td", "tfoot", "th",
                  "thead", "tr", "u", "ul", "font", "s", "hr", "div", "span"],
  :attributes => {
                  "div" => ["style"],
                  "colgroup"=>["span", "width"],
                  "col"=>["span", "width"],
                  "ul"=>["type"],
                  "a"=>["href", "title"],
                  "img"=>["align", "alt", "height", "src", "title", "width"],
                  "blockquote"=>["cite"],
                  "td"=>["abbr", "axis", "colspan", "rowspan", "width"],
                  "table"=>["summary", "width"],
                  "q"=>["cite"],
                  "ol"=>["start", "type"],
                  "th"=>["abbr", "axis", "colspan", "rowspan", "scope", "width"]
                 }
}