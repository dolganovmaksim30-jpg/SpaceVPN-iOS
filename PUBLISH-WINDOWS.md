# SpaceVPN — публикация с Windows PowerShell

## Вариант A — если репозиторий уже создан

Открой PowerShell в папке проекта:

```powershell
cd "C:\путь\к\SpaceVPN-iOS"
git status
git add .
git commit -m "SpaceVPN initial build"
git branch -M main
git push -u origin main
```

После push GitHub сам запустит Actions.

## Вариант B — создать новый репозиторий через сайт GitHub

1. На GitHub создай пустой repository, например `SpaceVPN-iOS`.
2. НЕ добавляй README, .gitignore или license.
3. В PowerShell:

```powershell
cd "C:\путь\к\SpaceVPN-iOS"

git init
git branch -M main
git add .
git commit -m "SpaceVPN initial build"
git remote add origin https://github.com/ТВОЙ_ЛОГИН/SpaceVPN-iOS.git
git push -u origin main
```

Если GitHub попросит авторизацию, используй свой GitHub login/token или Git Credential Manager.

## Что должно произойти

GitHub Actions запускается на macOS runner. GitHub предоставляет macOS-hosted runners, поэтому Windows-компьютер пользователя не должен иметь Xcode. XcodeGen создаёт `.xcodeproj` из `project.yml`.

После успешной сборки:

Actions → Build unsigned IPA → последний запуск → Artifacts → `SpaceVPN-unsigned-ipa`

Внутри будет:

`SpaceVPN-unsigned.ipa`

## Важно

Этот IPA НЕ подписан твоим eSign-сертификатом.

На iPhone:
1. скачать IPA;
2. открыть eSign;
3. импортировать IPA;
4. подписать своим сертификатом;
5. установить.

Если eSign выдаст ошибку подписи VPN, это означает, что provisioning/certificate не содержит Network Extension entitlement. Такой entitlement нельзя добавить простым изменением IPA.

## Если Actions упал

В PowerShell можно получить последние изменения и отправить исправление:

```powershell
git pull
git add .
git commit -m "Fix build"
git push
```
