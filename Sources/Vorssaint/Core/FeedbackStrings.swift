// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import Foundation

struct FeedbackStrings {
    let sectionTitle: String
    let sectionCaption: String
    let openButton: String
    let windowTitle: String
    let bugTitle: String
    let featureTitle: String
    let messageLabel: String
    let bugPlaceholder: String
    let featurePlaceholder: String
    let charactersFormat: String
    let includeDiagnostics: String
    let includeDiagnosticsCaption: String
    let whatSentTitle: String
    let whatSentBasic: String
    let whatSentDiagnostics: String
    let privacyNote: String
    let retentionNote: String
    let sendButton: String
    let sentTitle: String
    let sentCaption: String
    let copiedCaption: String
    let genericError: String
    let done: String
    let commandBug: String
    let commandFeature: String
    let commandSubtitle: String
    let diagnosticsChannelLabel: String
}

extension FeatureStrings {
    static func feedback(_ language: AppLanguage) -> FeedbackStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension FeedbackStrings {
    static let enUS = FeedbackStrings(
        sectionTitle: "Feedback",
        sectionCaption: "Report a bug or suggest a feature on GitHub, where the person who maintains Barforge can reply.",
        openButton: "Send feedback",
        windowTitle: "Send feedback",
        bugTitle: "Bug",
        featureTitle: "Feature idea",
        messageLabel: "What would you like to share?",
        bugPlaceholder: "Tell me what happened and what you expected.",
        featurePlaceholder: "Describe the idea and how it would help.",
        charactersFormat: "%d of 2000 characters",
        includeDiagnostics: "Include technical details",
        includeDiagnosticsCaption: "Fills in only the technical details shown below. It does not include logs.",
        whatSentTitle: "What goes into the form",
        whatSentBasic: "Your chosen category and the text above, as a new issue on GitHub.",
        whatSentDiagnostics: "The technical details listed below.",
        privacyNote: "Barforge sends nothing itself. Your browser opens the filled-in form on GitHub, and the issue exists only once you submit it there. You need a GitHub account.",
        retentionNote: "Issues on GitHub are public. Check the text before you submit it and remove anything you do not want to share.",
        sendButton: "Continue on GitHub",
        sentTitle: "Form opened in your browser",
        sentCaption: "Fill in the remaining fields on GitHub and submit the issue there. Thank you.",
        copiedCaption: "The text was too long for the link and is on your clipboard. Paste it into the form on GitHub, fill in the remaining fields and submit the issue there.",
        genericError: "Could not open the form in your browser.",
        done: "Done",
        commandBug: "Report a bug",
        commandFeature: "Suggest a feature",
        commandSubtitle: "Send feedback",
        diagnosticsChannelLabel: "Update channel"
    )

    static let ptBR = FeedbackStrings(
        sectionTitle: "Feedback",
        sectionCaption: "Relate um bug ou sugira um recurso no GitHub, onde quem mantém o Barforge pode responder.",
        openButton: "Enviar feedback",
        windowTitle: "Enviar feedback",
        bugTitle: "Bug",
        featureTitle: "Ideia de recurso",
        messageLabel: "O que você gostaria de compartilhar?",
        bugPlaceholder: "Conte o que aconteceu e o que você esperava.",
        featurePlaceholder: "Descreva a ideia e como ela ajudaria.",
        charactersFormat: "%d de 2000 caracteres",
        includeDiagnostics: "Incluir dados técnicos",
        includeDiagnosticsCaption: "Preenche somente os dados técnicos mostrados abaixo. Não inclui logs.",
        whatSentTitle: "O que vai para o formulário",
        whatSentBasic: "A categoria escolhida e o texto acima, como uma nova issue no GitHub.",
        whatSentDiagnostics: "Os dados técnicos listados abaixo.",
        privacyNote: "O Barforge não envia nada por conta própria. Seu navegador abre o formulário preenchido no GitHub, e a issue só existe quando você a envia lá. É preciso ter uma conta no GitHub.",
        retentionNote: "Issues no GitHub são públicas. Revise o texto antes de enviar e remova o que não quiser compartilhar.",
        sendButton: "Continuar no GitHub",
        sentTitle: "Formulário aberto no navegador",
        sentCaption: "Preencha os campos restantes no GitHub e envie a issue por lá. Obrigado.",
        copiedCaption: "O texto era longo demais para o link e está na área de transferência. Cole-o no formulário do GitHub, preencha os campos restantes e envie a issue por lá.",
        genericError: "Não foi possível abrir o formulário no navegador.",
        done: "Concluído",
        commandBug: "Relatar um bug",
        commandFeature: "Sugerir um recurso",
        commandSubtitle: "Enviar feedback",
        diagnosticsChannelLabel: "Canal de atualização"
    )

    static let tr = FeedbackStrings(
        sectionTitle: "Geri bildirim",
        sectionCaption: "Bir hatayı bildirin veya bir özellik önerin; GitHub’da Barforge bakımcısı yanıt verebilir.",
        openButton: "Geri bildirim gönder",
        windowTitle: "Geri bildirim gönder",
        bugTitle: "Hata",
        featureTitle: "Özellik fikri",
        messageLabel: "Ne paylaşmak istersiniz?",
        bugPlaceholder: "Ne olduğunu ve ne beklediğinizi anlatın.",
        featurePlaceholder: "Fikri ve nasıl yardımcı olacağını açıklayın.",
        charactersFormat: "2000 karakterden %d",
        includeDiagnostics: "Teknik ayrıntıları ekle",
        includeDiagnosticsCaption: "Yalnızca aşağıda gösterilen teknik ayrıntıları doldurur. Günlükler eklenmez.",
        whatSentTitle: "Forma eklenecekler",
        whatSentBasic: "Seçtiğiniz kategori ve yukarıdaki metin, GitHub’da yeni bir issue olarak.",
        whatSentDiagnostics: "Aşağıda listelenen teknik ayrıntılar.",
        privacyNote: "Barforge kendisi hiçbir şey göndermez. Tarayıcınız doldurulmuş formu GitHub’da açar; issue ancak siz orada gönderdiğinizde oluşur. Bir GitHub hesabı gerekir.",
        retentionNote: "GitHub’daki issue’lar herkese açıktır. Göndermeden önce metni kontrol edin ve paylaşmak istemediğiniz her şeyi çıkarın.",
        sendButton: "GitHub’da devam et",
        sentTitle: "Form tarayıcınızda açıldı",
        sentCaption: "Kalan alanları GitHub’da doldurun ve issue’yu orada gönderin. Teşekkürler.",
        copiedCaption: "Metin bağlantı için çok uzundu ve panoya kopyalandı. GitHub’daki forma yapıştırın, kalan alanları doldurun ve issue’yu orada gönderin.",
        genericError: "Form tarayıcıda açılamadı.",
        done: "Bitti",
        commandBug: "Hata bildir",
        commandFeature: "Özellik öner",
        commandSubtitle: "Geri bildirim gönder",
        diagnosticsChannelLabel: "Güncelleme kanalı"
    )

    static let ru = FeedbackStrings(
        sectionTitle: "Обратная связь",
        sectionCaption: "Сообщите об ошибке или предложите функцию на GitHub, где разработчик Barforge сможет ответить.",
        openButton: "Отправить отзыв",
        windowTitle: "Отправить отзыв",
        bugTitle: "Ошибка",
        featureTitle: "Идея функции",
        messageLabel: "Чем вы хотите поделиться?",
        bugPlaceholder: "Опишите, что произошло и чего вы ожидали.",
        featurePlaceholder: "Опишите идею и чем она поможет.",
        charactersFormat: "%d из 2000 символов",
        includeDiagnostics: "Добавить технические данные",
        includeDiagnosticsCaption: "Заполняет только технические данные, показанные ниже. Журналы не добавляются.",
        whatSentTitle: "Что попадёт в форму",
        whatSentBasic: "Выбранная категория и текст выше в виде нового issue на GitHub.",
        whatSentDiagnostics: "Технические данные, перечисленные ниже.",
        privacyNote: "Barforge сам ничего не отправляет. Браузер открывает заполненную форму на GitHub, а issue появится только после того, как вы отправите его там. Нужна учётная запись GitHub.",
        retentionNote: "Issues на GitHub публичны. Проверьте текст перед отправкой и удалите всё, чем не хотите делиться.",
        sendButton: "Продолжить на GitHub",
        sentTitle: "Форма открыта в браузере",
        sentCaption: "Заполните оставшиеся поля на GitHub и отправьте issue там. Спасибо.",
        copiedCaption: "Текст оказался слишком длинным для ссылки и скопирован в буфер обмена. Вставьте его в форму на GitHub, заполните оставшиеся поля и отправьте issue там.",
        genericError: "Не удалось открыть форму в браузере.",
        done: "Готово",
        commandBug: "Сообщить об ошибке",
        commandFeature: "Предложить функцию",
        commandSubtitle: "Отправить отзыв",
        diagnosticsChannelLabel: "Канал обновлений"
    )

    static let es = FeedbackStrings(
        sectionTitle: "Comentarios",
        sectionCaption: "Informa de un error o sugiere una función en GitHub, donde quien mantiene Barforge puede responder.",
        openButton: "Enviar comentarios",
        windowTitle: "Enviar comentarios",
        bugTitle: "Error",
        featureTitle: "Idea de función",
        messageLabel: "¿Qué quieres compartir?",
        bugPlaceholder: "Cuenta qué ocurrió y qué esperabas.",
        featurePlaceholder: "Describe la idea y cómo ayudaría.",
        charactersFormat: "%d de 2000 caracteres",
        includeDiagnostics: "Incluir datos técnicos",
        includeDiagnosticsCaption: "Rellena solo los datos técnicos mostrados abajo. No incluye registros.",
        whatSentTitle: "Qué irá en el formulario",
        whatSentBasic: "La categoría elegida y el texto anterior, como una nueva issue en GitHub.",
        whatSentDiagnostics: "Los datos técnicos indicados abajo.",
        privacyNote: "Barforge no envía nada por sí mismo. Tu navegador abre el formulario rellenado en GitHub, y la issue solo existe cuando la envías allí. Necesitas una cuenta de GitHub.",
        retentionNote: "Las issues de GitHub son públicas. Revisa el texto antes de enviarlo y quita lo que no quieras compartir.",
        sendButton: "Continuar en GitHub",
        sentTitle: "Formulario abierto en el navegador",
        sentCaption: "Completa los campos restantes en GitHub y envía la issue allí. Gracias.",
        copiedCaption: "El texto era demasiado largo para el enlace y está en el portapapeles. Pégalo en el formulario de GitHub, completa los campos restantes y envía la issue allí.",
        genericError: "No se pudo abrir el formulario en el navegador.",
        done: "Listo",
        commandBug: "Informar de un error",
        commandFeature: "Sugerir una función",
        commandSubtitle: "Enviar comentarios",
        diagnosticsChannelLabel: "Canal de actualización"
    )

    static let sk = FeedbackStrings(
        sectionTitle: "Spätná väzba",
        sectionCaption: "Nahláste chybu alebo navrhnite funkciu na GitHube, kde môže odpovedať osoba, ktorá udržiava Barforge.",
        openButton: "Poslať spätnú väzbu",
        windowTitle: "Poslať spätnú väzbu",
        bugTitle: "Chyba",
        featureTitle: "Nápad na funkciu",
        messageLabel: "Čo by ste chceli zdieľať?",
        bugPlaceholder: "Napíšte, čo sa stalo a čo ste očakávali.",
        featurePlaceholder: "Opíšte nápad a ako by pomohol.",
        charactersFormat: "%d z 2000 znakov",
        includeDiagnostics: "Zahrnúť technické detaily",
        includeDiagnosticsCaption: "Vyplní iba technické detaily zobrazené nižšie. Neobsahuje záznamy.",
        whatSentTitle: "Čo sa dostane do formulára",
        whatSentBasic: "Vybraná kategória a text vyššie ako nový issue na GitHube.",
        whatSentDiagnostics: "Technické detaily uvedené nižšie.",
        privacyNote: "Barforge sám nič neodosiela. Prehliadač otvorí vyplnený formulár na GitHube a issue vznikne až vtedy, keď ho tam odošlete. Potrebujete účet na GitHube.",
        retentionNote: "Issues na GitHube sú verejné. Pred odoslaním skontrolujte text a odstráňte všetko, čo nechcete zdieľať.",
        sendButton: "Pokračovať na GitHub",
        sentTitle: "Formulár sa otvoril v prehliadači",
        sentCaption: "Vyplňte zvyšné polia na GitHube a odošlite issue tam. Ďakujeme.",
        copiedCaption: "Text bol pre odkaz príliš dlhý a je v schránke. Vložte ho do formulára na GitHube, vyplňte zvyšné polia a odošlite issue tam.",
        genericError: "Formulár sa nepodarilo otvoriť v prehliadači.",
        done: "Hotovo",
        commandBug: "Nahlásiť chybu",
        commandFeature: "Navrhnúť funkciu",
        commandSubtitle: "Poslať spätnú väzbu",
        diagnosticsChannelLabel: "Kanál aktualizácií"
    )

    static let de = FeedbackStrings(
        sectionTitle: "Feedback",
        sectionCaption: "Melde einen Fehler oder schlage eine Funktion auf GitHub vor, wo der Barforge-Entwickler antworten kann.",
        openButton: "Feedback senden",
        windowTitle: "Feedback senden",
        bugTitle: "Fehler",
        featureTitle: "Funktionsidee",
        messageLabel: "Was möchtest du mitteilen?",
        bugPlaceholder: "Beschreibe, was passiert ist und was du erwartet hast.",
        featurePlaceholder: "Beschreibe die Idee und wie sie helfen würde.",
        charactersFormat: "%d von 2000 Zeichen",
        includeDiagnostics: "Technische Daten mitsenden",
        includeDiagnosticsCaption: "Trägt nur die unten gezeigten technischen Daten ein. Keine Protokolle.",
        whatSentTitle: "Was ins Formular kommt",
        whatSentBasic: "Die gewählte Kategorie und der Text oben, als neues Issue auf GitHub.",
        whatSentDiagnostics: "Die unten aufgeführten technischen Daten.",
        privacyNote: "Barforge sendet selbst nichts. Dein Browser öffnet das ausgefüllte Formular auf GitHub, und das Issue entsteht erst, wenn du es dort absendest. Dafür brauchst du ein GitHub-Konto.",
        retentionNote: "Issues auf GitHub sind öffentlich. Prüfe den Text vor dem Absenden und entferne alles, was du nicht teilen möchtest.",
        sendButton: "Weiter zu GitHub",
        sentTitle: "Formular im Browser geöffnet",
        sentCaption: "Fülle auf GitHub die restlichen Felder aus und sende das Issue dort ab. Danke.",
        copiedCaption: "Der Text war zu lang für den Link und liegt in der Zwischenablage. Füge ihn ins Formular auf GitHub ein, fülle die restlichen Felder aus und sende das Issue dort ab.",
        genericError: "Das Formular konnte nicht im Browser geöffnet werden.",
        done: "Fertig",
        commandBug: "Fehler melden",
        commandFeature: "Funktion vorschlagen",
        commandSubtitle: "Feedback senden",
        diagnosticsChannelLabel: "Update-Kanal"
    )

    static let fr = FeedbackStrings(
        sectionTitle: "Avis",
        sectionCaption: "Signalez un bug ou proposez une fonction sur GitHub, où la personne qui maintient Barforge peut répondre.",
        openButton: "Envoyer un avis",
        windowTitle: "Envoyer un avis",
        bugTitle: "Bug",
        featureTitle: "Idée de fonction",
        messageLabel: "Que souhaitez-vous partager\u{00A0}?",
        bugPlaceholder: "Décrivez ce qui s’est passé et ce que vous attendiez.",
        featurePlaceholder: "Décrivez l’idée et son utilité.",
        charactersFormat: "%d caractères sur 2000",
        includeDiagnostics: "Inclure les données techniques",
        includeDiagnosticsCaption: "Remplit uniquement les données techniques affichées ci-dessous. Aucun journal.",
        whatSentTitle: "Ce qui ira dans le formulaire",
        whatSentBasic: "La catégorie choisie et le texte ci-dessus, sous forme de nouvelle issue sur GitHub.",
        whatSentDiagnostics: "Les données techniques listées ci-dessous.",
        privacyNote: "Barforge n’envoie rien lui-même. Votre navigateur ouvre le formulaire prérempli sur GitHub, et l’issue n’existe qu’une fois que vous l’y envoyez. Un compte GitHub est nécessaire.",
        retentionNote: "Les issues sur GitHub sont publiques. Relisez le texte avant de l’envoyer et retirez ce que vous ne voulez pas partager.",
        sendButton: "Continuer sur GitHub",
        sentTitle: "Formulaire ouvert dans le navigateur",
        sentCaption: "Remplissez les champs restants sur GitHub et envoyez l’issue depuis là. Merci.",
        copiedCaption: "Le texte était trop long pour le lien et se trouve dans le presse-papiers. Collez-le dans le formulaire sur GitHub, remplissez les champs restants et envoyez l’issue depuis là.",
        genericError: "Impossible d’ouvrir le formulaire dans le navigateur.",
        done: "Terminé",
        commandBug: "Signaler un bug",
        commandFeature: "Suggérer une fonction",
        commandSubtitle: "Envoyer un avis",
        diagnosticsChannelLabel: "Canal de mise à jour"
    )

    static let it = FeedbackStrings(
        sectionTitle: "Feedback",
        sectionCaption: "Segnala un bug o proponi una funzione su GitHub, dove chi mantiene Barforge può rispondere.",
        openButton: "Invia feedback",
        windowTitle: "Invia feedback",
        bugTitle: "Bug",
        featureTitle: "Idea per una funzione",
        messageLabel: "Cosa vuoi condividere?",
        bugPlaceholder: "Descrivi cosa è successo e cosa ti aspettavi.",
        featurePlaceholder: "Descrivi l’idea e come potrebbe aiutare.",
        charactersFormat: "%d di 2000 caratteri",
        includeDiagnostics: "Includi dati tecnici",
        includeDiagnosticsCaption: "Compila solo i dati tecnici mostrati sotto. Non include registri.",
        whatSentTitle: "Cosa finirà nel modulo",
        whatSentBasic: "La categoria scelta e il testo qui sopra, come nuova issue su GitHub.",
        whatSentDiagnostics: "I dati tecnici elencati qui sotto.",
        privacyNote: "Barforge non invia nulla da solo. Il browser apre il modulo già compilato su GitHub e la issue esiste solo quando la invii lì. Serve un account GitHub.",
        retentionNote: "Le issue su GitHub sono pubbliche. Controlla il testo prima di inviarlo e togli ciò che non vuoi condividere.",
        sendButton: "Continua su GitHub",
        sentTitle: "Modulo aperto nel browser",
        sentCaption: "Compila i campi rimanenti su GitHub e invia lì la issue. Grazie.",
        copiedCaption: "Il testo era troppo lungo per il link ed è negli appunti. Incollalo nel modulo su GitHub, compila i campi rimanenti e invia lì la issue.",
        genericError: "Impossibile aprire il modulo nel browser.",
        done: "Fine",
        commandBug: "Segnala un bug",
        commandFeature: "Suggerisci una funzione",
        commandSubtitle: "Invia feedback",
        diagnosticsChannelLabel: "Canale di aggiornamento"
    )

    static let ja = FeedbackStrings(
        sectionTitle: "フィードバック",
        sectionCaption: "GitHub で不具合を報告したり機能を提案したりできます。Barforge の開発者がそこで返信できます。",
        openButton: "フィードバックを送信",
        windowTitle: "フィードバックを送信",
        bugTitle: "不具合",
        featureTitle: "機能のアイデア",
        messageLabel: "共有したい内容を入力してください",
        bugPlaceholder: "何が起き、どうなることを期待していたかを説明してください。",
        featurePlaceholder: "アイデアと、どのように役立つかを説明してください。",
        charactersFormat: "2000文字中%d文字",
        includeDiagnostics: "技術情報を含める",
        includeDiagnosticsCaption: "下に表示される技術情報だけを入力します。ログは含みません。",
        whatSentTitle: "フォームに入る内容",
        whatSentBasic: "選択した種類と上の文章を、GitHub の新しい Issue として入力します。",
        whatSentDiagnostics: "下に表示される技術情報。",
        privacyNote: "Barforge 自体は何も送信しません。入力済みのフォームがブラウザで GitHub に開き、そこで送信して初めて Issue が作成されます。GitHub アカウントが必要です。",
        retentionNote: "GitHub の Issue は公開されます。送信前に文章を確認し、共有したくない内容は削除してください。",
        sendButton: "GitHub で続ける",
        sentTitle: "ブラウザでフォームを開きました",
        sentCaption: "GitHub で残りの項目を入力し、そこで Issue を送信してください。ありがとうございます。",
        copiedCaption: "文章がリンクには長すぎたため、クリップボードにコピーしました。GitHub のフォームに貼り付け、残りの項目を入力してから Issue を送信してください。",
        genericError: "ブラウザでフォームを開けませんでした。",
        done: "完了",
        commandBug: "不具合を報告",
        commandFeature: "機能を提案",
        commandSubtitle: "フィードバックを送信",
        diagnosticsChannelLabel: "アップデートチャンネル"
    )

    static let ko = FeedbackStrings(
        sectionTitle: "피드백",
        sectionCaption: "GitHub에서 버그를 신고하거나 기능을 제안하면 Barforge 관리자가 답변할 수 있습니다.",
        openButton: "피드백 보내기",
        windowTitle: "피드백 보내기",
        bugTitle: "버그",
        featureTitle: "기능 아이디어",
        messageLabel: "무엇을 공유하시겠습니까?",
        bugPlaceholder: "무슨 일이 있었고 무엇을 기대했는지 알려 주세요.",
        featurePlaceholder: "아이디어와 도움이 되는 이유를 설명해 주세요.",
        charactersFormat: "2000자 중 %d자",
        includeDiagnostics: "기술 정보 포함",
        includeDiagnosticsCaption: "아래에 표시된 기술 정보만 채웁니다. 로그는 포함하지 않습니다.",
        whatSentTitle: "양식에 들어가는 내용",
        whatSentBasic: "선택한 종류와 위의 글이 GitHub의 새 이슈로 들어갑니다.",
        whatSentDiagnostics: "아래에 표시된 기술 정보.",
        privacyNote: "Barforge는 직접 아무것도 보내지 않습니다. 브라우저가 GitHub에서 채워진 양식을 열고, 그곳에서 제출해야 이슈가 만들어집니다. GitHub 계정이 필요합니다.",
        retentionNote: "GitHub 이슈는 공개됩니다. 제출하기 전에 글을 확인하고 공유하고 싶지 않은 내용은 지워 주세요.",
        sendButton: "GitHub에서 계속",
        sentTitle: "브라우저에서 양식을 열었습니다",
        sentCaption: "GitHub에서 나머지 항목을 채우고 이슈를 제출해 주세요. 감사합니다.",
        copiedCaption: "글이 링크에 넣기에는 너무 길어 클립보드에 복사했습니다. GitHub 양식에 붙여 넣고 나머지 항목을 채운 뒤 이슈를 제출해 주세요.",
        genericError: "브라우저에서 양식을 열 수 없습니다.",
        done: "완료",
        commandBug: "버그 신고",
        commandFeature: "기능 제안",
        commandSubtitle: "피드백 보내기",
        diagnosticsChannelLabel: "업데이트 채널"
    )

    static let zhHans = FeedbackStrings(
        sectionTitle: "反馈",
        sectionCaption: "在 GitHub 上报告错误或建议功能，Barforge 的维护者可以在那里回复。",
        openButton: "发送反馈",
        windowTitle: "发送反馈",
        bugTitle: "错误",
        featureTitle: "功能建议",
        messageLabel: "你想分享什么？",
        bugPlaceholder: "说明发生了什么以及你原本的预期。",
        featurePlaceholder: "说明你的想法以及它能带来什么帮助。",
        charactersFormat: "已输入 %d/2000 个字符",
        includeDiagnostics: "包含技术信息",
        includeDiagnosticsCaption: "仅填入下方显示的技术信息。不包含日志。",
        whatSentTitle: "将填入表单的内容",
        whatSentBasic: "所选类别和上方文字，作为 GitHub 上的新 Issue。",
        whatSentDiagnostics: "下方列出的技术信息。",
        privacyNote: "Barforge 本身不发送任何内容。浏览器会在 GitHub 上打开已填好的表单，只有你在那里提交后才会创建 Issue。需要 GitHub 账户。",
        retentionNote: "GitHub 上的 Issue 是公开的。提交前请检查文字，删除你不想分享的内容。",
        sendButton: "在 GitHub 上继续",
        sentTitle: "已在浏览器中打开表单",
        sentCaption: "请在 GitHub 上填写其余字段，并在那里提交 Issue。谢谢。",
        copiedCaption: "文字太长，无法放入链接，已复制到剪贴板。请将其粘贴到 GitHub 表单中，填写其余字段后在那里提交 Issue。",
        genericError: "无法在浏览器中打开表单。",
        done: "完成",
        commandBug: "报告错误",
        commandFeature: "建议功能",
        commandSubtitle: "发送反馈",
        diagnosticsChannelLabel: "更新渠道"
    )

    static let zhTW = FeedbackStrings(
        sectionTitle: "意見回饋",
        sectionCaption: "在 GitHub 上回報錯誤或建議功能，Barforge 的維護者可以在那裡回覆。",
        openButton: "傳送意見",
        windowTitle: "傳送意見",
        bugTitle: "錯誤",
        featureTitle: "功能建議",
        messageLabel: "你想分享什麼？",
        bugPlaceholder: "說明發生了什麼以及你原本的預期。",
        featurePlaceholder: "說明你的想法以及它能帶來什麼幫助。",
        charactersFormat: "已輸入 %d/2000 個字元",
        includeDiagnostics: "包含技術資訊",
        includeDiagnosticsCaption: "只填入下方顯示的技術資料。不包含記錄。",
        whatSentTitle: "將填入表單的內容",
        whatSentBasic: "所選類別與上方文字，作為 GitHub 上的新 Issue。",
        whatSentDiagnostics: "下方列出的技術資訊。",
        privacyNote: "Barforge 本身不會傳送任何內容。瀏覽器會在 GitHub 上開啟已填好的表單，只有你在那裡送出後才會建立 Issue。需要 GitHub 帳號。",
        retentionNote: "GitHub 上的 Issue 是公開的。送出前請檢查文字，刪除你不想分享的內容。",
        sendButton: "在 GitHub 上繼續",
        sentTitle: "已在瀏覽器中開啟表單",
        sentCaption: "請在 GitHub 上填寫其餘欄位，並在那裡送出 Issue。謝謝。",
        copiedCaption: "文字太長，無法放入連結，已拷貝到剪貼簿。請將它貼到 GitHub 表單中，填寫其餘欄位後在那裡送出 Issue。",
        genericError: "無法在瀏覽器中開啟表單。",
        done: "完成",
        commandBug: "回報錯誤",
        commandFeature: "建議功能",
        commandSubtitle: "傳送意見",
        diagnosticsChannelLabel: "更新頻道"
    )

    static let zhHK = FeedbackStrings(
        sectionTitle: "意見回饋",
        sectionCaption: "在 GitHub 上報告錯誤或建議功能，Barforge 的維護者可以在那裡回覆。",
        openButton: "傳送意見",
        windowTitle: "傳送意見",
        bugTitle: "錯誤",
        featureTitle: "功能建議",
        messageLabel: "你想分享甚麼？",
        bugPlaceholder: "說明發生了甚麼以及你原本的預期。",
        featurePlaceholder: "說明你的想法以及它能帶來甚麼幫助。",
        charactersFormat: "已輸入 %d/2000 個字元",
        includeDiagnostics: "包含技術資料",
        includeDiagnosticsCaption: "只填入下方顯示的技術資料。不包含記錄。",
        whatSentTitle: "將填入表單的內容",
        whatSentBasic: "所選類別與上方文字，作為 GitHub 上的新 Issue。",
        whatSentDiagnostics: "下方列出的技術資料。",
        privacyNote: "Barforge 本身不會傳送任何內容。瀏覽器會在 GitHub 上開啟已填好的表單，只有你在那裡送出後才會建立 Issue。需要 GitHub 帳戶。",
        retentionNote: "GitHub 上的 Issue 是公開的。送出前請檢查文字，刪除你不想分享的內容。",
        sendButton: "在 GitHub 上繼續",
        sentTitle: "已在瀏覽器中開啟表單",
        sentCaption: "請在 GitHub 上填寫其餘欄位，並在那裡送出 Issue。謝謝。",
        copiedCaption: "文字太長，無法放入連結，已拷貝到剪貼簿。請將它貼到 GitHub 表單中，填寫其餘欄位後在那裡送出 Issue。",
        genericError: "無法在瀏覽器中開啟表單。",
        done: "完成",
        commandBug: "報告錯誤",
        commandFeature: "建議功能",
        commandSubtitle: "傳送意見",
        diagnosticsChannelLabel: "更新頻道"
    )
    static let uk = FeedbackStrings(
        sectionTitle: "Відгук",
        sectionCaption: "Повідомте про помилку або запропонуйте функцію на GitHub, де розробник Barforge зможе відповісти.",
        openButton: "Надіслати відгук",
        windowTitle: "Надіслати відгук",
        bugTitle: "Помилка",
        featureTitle: "Ідея функції",
        messageLabel: "Чим би ви хотіли поділитися?",
        bugPlaceholder: "Розкажіть, що сталося та що ви очікували.",
        featurePlaceholder: "Опишіть ідею та як вона допоможе.",
        charactersFormat: "%d з 2000 символів",
        includeDiagnostics: "Включити технічні деталі",
        includeDiagnosticsCaption: "Заповнює лише технічні деталі, показані нижче. Вони не включають журнали.",
        whatSentTitle: "Що потрапить у форму",
        whatSentBasic: "Обрана категорія та текст вище як новий issue на GitHub.",
        whatSentDiagnostics: "Технічні деталі, перелічені нижче.",
        privacyNote: "Barforge сам нічого не надсилає. Браузер відкриває заповнену форму на GitHub, а issue з’явиться лише тоді, коли ви надішлете його там. Потрібен обліковий запис GitHub.",
        retentionNote: "Issues на GitHub публічні. Перевірте текст перед надсиланням і приберіть усе, чим не хочете ділитися.",
        sendButton: "Продовжити на GitHub",
        sentTitle: "Форму відкрито в браузері",
        sentCaption: "Заповніть решту полів на GitHub і надішліть issue там. Дякуємо.",
        copiedCaption: "Текст був задовгим для посилання, тому його скопійовано в буфер обміну. Вставте його у форму на GitHub, заповніть решту полів і надішліть issue там.",
        genericError: "Не вдалося відкрити форму в браузері.",
        done: "Готово",
        commandBug: "Повідомити про помилку",
        commandFeature: "Запропонувати функцію",
        commandSubtitle: "Надіслати відгук",
        diagnosticsChannelLabel: "Канал оновлення"
    )
}
