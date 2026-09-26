$content = Get-Content 'C:\Users\tiren\OneDrive\Documents\BANT\store\useBantStore.ts' -Raw
$content = $content -replace 'signIn: \(input: \{ email: string; password: string \}\) => Promise<boolean>;', 'signIn: (input: { email: string; password: string }) => Promise<boolean>;`n  signInWithGoogle: () => Promise<void>;'
$content = $content -replace 'saveOnboardingProfile: \(input: \{ displayName: string; username: string; bio: string \}\) => Promise<boolean>;', 'saveOnboardingProfile: (input: { displayName: string; username: string; bio: string; avatarUrl?: string }) => Promise<boolean>;'
$content = $content -replace 'saveOnboardingProfile: async \(\{ displayName, username, bio \}\) => {', 'saveOnboardingProfile: async ({ displayName, username, bio, avatarUrl }) => {'
$content = $content -replace 'bio: bio\.trim\(\) \|\| null,', 'bio: bio.trim() || null, avatar_url: avatarUrl || null,'
Set-Content 'C:\Users\tiren\OneDrive\Documents\BANT\store\useBantStore.ts' $content
