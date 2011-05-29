# encoding: utf-8
class CustomHtml
  include Mongoid::Document

  embedded_in :group, :inverse_of => :custom_html

  identity :type => String
  field :top_bar, :type => String, :default => "[[faq|FAQ]]"

  field :question_prompt, :type => Hash, :default => {"en" => "what's your question? be descriptive.",
                                           "el" => "ποια είναι η απορία σας; περιγράψτε την.",
                                           "es" => "¿cual es tu pregunta? por favor se descriptivo.",
                                           "fr" => "quelle est votre question? soyez descriptif.",
                                           "pt" => "qual é a sua pergunta? seja descritivo.",
                                           "ja" => "あなたの質問はなんですか？"}
  field :question_help, :type => Hash, :default => { # FIXME: move this to its own yml
"en" => "Provide as much details as possible so that it will have more
chance to be answered instead of being endlessly discussed.
Try to be clear and simple.",
"el" => "Δώστε όσες περισσότερες λεπτομέρειες γίνεται ώστε να έχει περισσότερες
πιθανότητες να απαντηθεί από το να συζητιέται ες αεί.
Προσπαθήστε να είστε σαφής και απλός.",
"es" => "Sobre que es tu pregunta?
provee tantos detalles como puedas para tener más suerte
de conseguir una respuesta y no una discusion sin fin.
intenta ser claro y simple",
"fr" => "Sur quoi porte votre question?
Donnez autants de détails que possible afin d'avoir plus de chance
d'obtenir une réponse et non une discussion sans fin. Éssayer d'être clair et simple.",
"pt" => "",
"ja" => "できるだけシンプルに、かつ明確にすることで論点が明確になって議論が発展します。そうすることで詳細な回答が受けられるようになります。"
  }

  field :head, :type => Hash, :default => {}
  field :footer, :type => Hash, :default => {}
  field :head_tag, :type => String
end
