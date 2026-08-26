import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

class PrivacyTrustScreen extends StatelessWidget {
  const PrivacyTrustScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 · AI 데이터 보호')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.verified_user_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '데이터 보호 원칙',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '개인정보와 업무 데이터를 안전하게 처리하기 위한 기본 원칙입니다. '
                                '외부 AI 서비스를 사용하는 경우 AI 처리에 필요한 정보만 전송하며, '
                                '이메일·전화번호 등 탐지 가능한 개인정보는 전송 전에 자동으로 마스킹합니다.',
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PolicyCard(
                    icon: Icons.policy_outlined,
                    title: '개인정보처리방침',
                    children: const [
                      _PolicySection(
                        title: '1. 처리 목적',
                        body: 'VOC 등록·조회·분류·답변 작성, 지식베이스 검색, 운영 통계, 동기화 및 사용자가 실행한 업무 자동화를 위해 필요한 데이터를 처리합니다.',
                      ),
                      _PolicySection(
                        title: '2. 처리될 수 있는 정보',
                        body: 'VOC 제목·본문·고객/프로젝트 정보·담당자·처리 상태·답변, 지식베이스 문서, 사용자가 가져온 파일에서 추출된 업무 내용, AI·협업도구·동기화 설정 정보가 포함될 수 있습니다. VOC 원문에 개인정보가 포함될 수 있으므로 업무에 불필요한 개인정보 입력은 최소화해야 합니다.',
                      ),
                      _PolicySection(
                        title: '3. 저장 및 보유',
                        body: '주요 업무 데이터와 설정은 앱이 사용하는 로컬 저장소에 보관됩니다. 실제 보유·삭제 기준은 이 앱을 사용하는 조직의 개인정보 보유정책과 내부 절차를 따라야 합니다.',
                      ),
                      _PolicySection(
                        title: '4. 외부 서비스 전송',
                        body: 'OpenAI, Gemini, Claude 등 외부 AI 제공자를 선택하면 AI 분석과 답변 생성에 필요한 텍스트가 해당 제공자 API로 전송될 수 있습니다. JIRA, Confluence, Outlook, Webhook 등 외부 연동을 활성화한 경우에도 해당 기능 수행에 필요한 데이터가 연결된 시스템으로 전달될 수 있습니다. Ollama는 사용자가 지정한 자체 엔드포인트를 사용합니다.',
                      ),
                      _PolicySection(
                        title: '5. 개인정보 보호조치',
                        body: '외부 AI 요청을 만들 때 이메일, 전화번호, 주민등록번호, 카드번호 및 이름으로 명시된 값 등 탐지 가능한 개인정보를 자동 마스킹합니다. 마스킹은 외부 전송용 데이터에 적용되며 로컬 원본은 변경하지 않습니다. 자동 탐지는 보조수단이므로 모든 형태의 개인정보를 완전히 탐지한다고 보장할 수 없습니다.',
                      ),
                      _PolicySection(
                        title: '6. 정보주체 권리 및 문의',
                        body: '열람·정정·삭제·처리정지 등 개인정보 관련 요청과 개인정보 보호책임자 또는 담당부서 정보는 이 앱을 사용하는 조직의 공식 개인정보처리방침과 내부 절차를 따릅니다.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PolicyCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'AI 데이터 처리 안내',
                    children: const [
                      _PolicySection(
                        title: 'AI가 사용하는 정보',
                        body: '질문, VOC 제목과 내용, 유사한 과거 VOC, 지식베이스, 대화 맥락과 분석에 필요한 운영 정보가 AI 요청에 포함될 수 있습니다. 외부 AI 제공자로 전송되는 데이터에는 개인정보 마스킹을 먼저 적용합니다.',
                      ),
                      _PolicySection(
                        title: 'AI의 역할',
                        body: 'AI는 분류, 긴급도·담당자 추천, 유사사례 검색, 답변 초안, 요약 및 운영 인사이트 작성을 지원합니다. 중요한 사실 확인과 최종 업무 판단은 사용자가 검토하는 것을 원칙으로 합니다.',
                      ),
                      _PolicySection(
                        title: '자동 처리',
                        body: '사용자가 자동화 기능을 활성화한 경우 VOC 등록 후 AI 답변 초안 생성이나 연동 시스템 전달이 자동으로 실행될 수 있습니다. 각 자동화 기능은 설정 화면에서 켜거나 끌 수 있습니다.',
                      ),
                      _PolicySection(
                        title: '외부 AI 제공자',
                        body: '외부 AI를 선택한 경우 전송 이후의 데이터 처리 조건은 해당 제공자와 조직 간 계약, 계정 설정 및 제공자 정책의 영향을 받을 수 있습니다. 민감하거나 불필요한 개인정보는 원문 입력 단계에서도 제외하는 것을 권장합니다.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: colorScheme.primary),
                              const SizedBox(width: 10),
                              Text(
                                '앱 정보 및 라이선스',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text('${AppConstants.appName}  v${AppConstants.appVersion}'),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () => showLicensePage(
                              context: context,
                              applicationName: AppConstants.appName,
                              applicationVersion: AppConstants.appVersion,
                            ),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('오픈소스 라이선스 보기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '시행일: 2026-08-18\n'
                      '이 화면은 앱의 데이터 처리 구조를 설명합니다. 개인정보처리자 명칭, 개인정보 보호책임자, 조직별 보유기간, 국외이전 세부사항 등 조직별 항목은 실제 적용 환경의 공식 개인정보처리방침에서 최종 확정해야 합니다.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _PolicyCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
