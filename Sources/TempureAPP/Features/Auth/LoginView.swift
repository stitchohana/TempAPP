#if canImport(SwiftUI)
import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    public init(viewModel: LoginViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            VStack(spacing: 8) {
                Text("Tempure")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(viewModel.isRegisterMode ? "创建账号后开始记录体温" : "使用账号密码安全登录")
                    .font(TempureTypography.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("账号", text: $viewModel.account)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                SecureField("密码（至少6位）", text: $viewModel.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                if viewModel.isRegisterMode {
                    SecureField("确认密码", text: $viewModel.confirmPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    Task { await viewModel.submit() }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(viewModel.isRegisterMode ? "注册并登录" : "登录")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TempureColors.dustyRose)
                .disabled(viewModel.isSubmitting)

                Button(viewModel.isRegisterMode ? "已有账号？去登录" : "没有账号？去注册") {
                    viewModel.toggleMode()
                }
                .buttonStyle(.plain)
                .font(TempureTypography.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("继续即表示你同意《隐私政策》和《服务条款》")
                .font(TempureTypography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .alert(
            "提示",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("知道了", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
#endif
