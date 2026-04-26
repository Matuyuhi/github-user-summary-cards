/// Template with a `%FORK_FILTER%` placeholder that is replaced at runtime
/// with either ", isFork: false" (default) or "" (when --include-forks).
pub const profile_query_template =
    \\query($login: String!, $from: DateTime!, $to: DateTime!) {
    \\  user(login: $login) {
    \\    name
    \\    login
    \\    bio
    \\    avatarUrl
    \\    createdAt
    \\    followers { totalCount }
    \\    following { totalCount }
    \\    pullRequests { totalCount }
    \\    issues { totalCount }
    \\    repositories(first: 100, ownerAffiliations: [OWNER]%FORK_FILTER%, orderBy: {field: STARGAZERS, direction: DESC}) {
    \\      totalCount
    \\      nodes {
    \\        name
    \\        description
    \\        url
    \\        stargazerCount
    \\        forkCount
    \\        primaryLanguage { name color }
    \\        languages(first: 10, orderBy: {field: SIZE, direction: DESC}) {
    \\          edges { size node { name color } }
    \\        }
    \\      }
    \\    }
    \\    contributionsCollection(from: $from, to: $to) {
    \\      totalCommitContributions
    \\      totalPullRequestContributions
    \\      totalIssueContributions
    \\      totalRepositoriesWithContributedCommits
    \\      contributionCalendar {
    \\        totalContributions
    \\        weeks {
    \\          contributionDays { date contributionCount weekday }
    \\        }
    \\      }
    \\      commitContributionsByRepository(maxRepositories: 100) {
    \\        repository { nameWithOwner primaryLanguage { name color } }
    \\        contributions(first: 100) { nodes { commitCount } }
    \\      }
    \\    }
    \\  }
    \\  rateLimit { remaining resetAt }
    \\}
;

pub const contributions_query =
    \\query($login: String!, $from: DateTime!, $to: DateTime!) {
    \\  user(login: $login) {
    \\    contributionsCollection(from: $from, to: $to) {
    \\      totalCommitContributions
    \\      totalRepositoriesWithContributedCommits
    \\      contributionCalendar {
    \\        totalContributions
    \\        weeks {
    \\          contributionDays { date contributionCount weekday }
    \\        }
    \\      }
    \\      commitContributionsByRepository(maxRepositories: 100) {
    \\        repository { nameWithOwner primaryLanguage { name color } }
    \\        contributions(first: 100) { nodes { commitCount } }
    \\      }
    \\    }
    \\  }
    \\}
;
