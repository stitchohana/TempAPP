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
                Text("记录每一天的体温变化")
                    .font(TempureTypography.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("邮箱", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 8) {
                    TextField("6位验证码", text: $viewModel.code)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    Button(viewModel.countdown > 0 ? "\(viewModel.countdown)s" : "发送验证码") {
                        Task { await viewModel.sendCode() }
                    }
                    .disabled(viewModel.isSendingCode || viewModel.countdown > 0)
                    .buttonStyle(.bordered)
                }

                Button {
                    Task { await viewModel.login() }
                } label: {
                    if viewModel.isLoggingIn {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("登录 / 注册")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TempureColors.dustyRose)
                .disabled(viewModel.isLoggingIn)

                Button("使用 Apple 登录（即将上线）") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
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
