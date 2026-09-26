$content = Get-Content 'C:\Users\tiren\OneDrive\Documents\BANT\store\useBantStore.ts' -Raw
# Fix signInWithGoogle - add it properly without backticks
$content = $content -replace 'signIn: \(input: \{ email: string; password: string \}\) => Promise<boolean>;', "signIn: (input: { email: string; password: string }) => Promise<boolean>;`r`n  signInWithGoogle: () => Promise<void>;"
# Fix saveOnboardingProfile type
$content = $content -replace 'saveOnboardingProfile: \(input: \{ displayName: string; username: string; bio: string \}\) => Promise<boolean>;', 'saveOnboardingProfile: (input: { displayName: string; username: string; bio: string; avatarUrl?: string }) => Promise<boolean>;'
# Fix saveOnboardingProfile implementation
$content = $content -replace 'saveOnboardingProfile: async \(\{ displayName, username, bio \}\) => {', 'saveOnboardingProfile: async ({ displayName, username, bio, avatarUrl }) => {'
$content = $content -replace 'bio: bio\.trim\(\) \|\| null,', 'bio: bio.trim() || null, avatar_url: avatarUrl || null,'
Set-Content 'C:\Users\tiren\OneDrive\Documents\BANT\store\useBantStore.ts' $content
